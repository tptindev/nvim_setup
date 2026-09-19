-- C++ splits a function between a declaration and a definition, and nothing in
-- the toolchain writes the second one for you: clangd's `DefineOutline` only
-- moves a body that *already exists* out of a class, and neither clangd nor the
-- LSP protocol has a change-signature refactor at all -- editing a parameter
-- list means finding the other side by hand and retyping it there.
--
-- Both operations are pure syntax, so they are done here off the Treesitter
-- tree. Every part of a signature is taken as a byte range out of the parsed
-- source rather than re-printed from the tree, so macros, attributes and
-- elaborate types survive untouched; only what *must* differ between the two
-- sides is rewritten -- the leading `virtual`/`static`/`explicit`/`inline`, the
-- trailing `override`/`final`, default arguments, and the `Class::` qualifier.
--
-- The `cpp` grammar parses C as well, so C buffers go through the same code.
local M = {}

---Declaration-ish nodes that can carry a function declarator.
local function_nodes = {
    declaration = true,
    field_declaration = true,
    function_definition = true,
}

---Nodes to descend into while looking for functions. `friend_declaration` is
---here rather than in the scope table on purpose: a friend is not a member, so
---its definition must *not* be qualified with the surrounding class.
local containers = {
    translation_unit = true,
    declaration_list = true,
    field_declaration_list = true,
    namespace_definition = true,
    linkage_specification = true,
    friend_declaration = true,
    class_specifier = true,
    struct_specifier = true,
    union_specifier = true,
    preproc_if = true,
    preproc_ifdef = true,
    preproc_else = true,
    preproc_elif = true,
}

local class_nodes = {
    class_specifier = true,
    struct_specifier = true,
    union_specifier = true,
}

---Specifiers that may only appear on one of the two sides.
local declaration_only_specifiers = {
    virtual = true,
    static = true,
    explicit = true,
    friend = true,
    -- `inline` on a member declaration is redundant; carried into a .cpp it
    -- turns a normal function into one that must be defined in every
    -- translation unit that uses it, which is an ODR bug waiting to happen.
    inline = true,
}

local header_extensions = {
    h = true,
    hpp = true,
    hh = true,
    hxx = true,
    ["h++"] = true,
    hp = true,
    inl = true,
    ipp = true,
    tpp = true,
}

local source_for = {
    h = { "cpp", "c", "cc", "cxx" },
    hpp = { "cpp", "cxx", "cc" },
    hh = { "cc", "cpp" },
    hxx = { "cxx", "cpp" },
    ["h++"] = { "c++", "cpp" },
    hp = { "cpp" },
    inl = { "cpp" },
    ipp = { "cpp" },
    tpp = { "cpp" },
}

local header_for = {
    c = { "h" },
    cpp = { "h", "hpp", "hh", "hxx" },
    cc = { "h", "hh", "hpp" },
    cxx = { "h", "hxx", "hpp" },
    ["c++"] = { "h++", "hpp", "h" },
}

---Directory pairs that projects split headers and sources across. Applied in
---both directions, on a single path component.
local directory_pairs = {
    { "include", "src" },
    { "include", "source" },
    { "include", "sources" },
    { "inc", "src" },
    { "headers", "src" },
    { "public", "private" },
}

---@param text string
---@return string
local function squash(text)
    text = text:gsub("%s+", " ")
    return (text:gsub("^ +", ""):gsub(" +$", ""))
end

---@param node TSNode|nil
---@param buf integer
---@return string
local function text_of(node, buf)
    if not node then
        return ""
    end

    local ok, text = pcall(vim.treesitter.get_node_text, node, buf)

    return ok and text or ""
end

---@param buf integer
---@return string
local function range_text(buf, srow, scol, erow, ecol)
    local ok, lines = pcall(vim.api.nvim_buf_get_text, buf, srow, scol, erow, ecol, {})

    if not ok then
        return ""
    end

    return table.concat(lines, "\n")
end

---Text from the start of `from` up to the start of `to`.
---@param buf integer
---@param from TSNode
---@param to TSNode
---@return string
local function text_before(buf, from, to)
    local srow, scol = from:start()
    local erow, ecol = to:start()

    return range_text(buf, srow, scol, erow, ecol)
end

---@param buf integer
---@return TSNode|nil
local function root_of(buf)
    local ok, parser = pcall(vim.treesitter.get_parser, buf, "cpp")

    if not ok or not parser then
        return nil
    end

    local tree = parser:parse()[1]

    return tree and tree:root() or nil
end

---The declarator of the function this node declares, if any. Parameter lists
---and bodies are skipped so a function pointer parameter or a lambda inside a
---body is never mistaken for the declaration itself.
---@param node TSNode
---@return TSNode|nil
local function find_function_declarator(node)
    if node:type() == "function_declarator" then
        return node
    end

    for child in node:iter_children() do
        local kind = child:type()

        if kind ~= "parameter_list" and kind ~= "compound_statement" and not containers[kind] then
            local found = find_function_declarator(child)

            if found then
                return found
            end
        end
    end

    return nil
end

---@param node TSNode
---@return TSNode|nil
local function first_identifier(node)
    if node:type() == "identifier" then
        return node
    end

    for child in node:iter_children() do
        local found = first_identifier(child)

        if found then
            return found
        end
    end

    return nil
end

---A parameter with its name removed, whitespace and all, so two overloads can
---be told apart by their types alone.
---@param buf integer
---@param node TSNode
---@return string
local function parameter_type(buf, node)
    local text = text_of(node, buf)
    local declarator = node:field("declarator")[1]

    if declarator then
        local name = first_identifier(declarator)

        if name then
            local _, _, node_byte = node:start()
            local _, _, name_byte = name:start()
            local offset = name_byte - node_byte
            local name_text = text_of(name, buf)

            if offset >= 0 and offset <= #text then
                text = text:sub(1, offset) .. text:sub(offset + #name_text + 1)
            end
        end
    end

    return (text:gsub("%s+", ""))
end

---@param buf integer
---@param list TSNode|nil
---@return { written: string, stripped: string, types: string[], count: integer }
local function parameters(buf, list)
    local written, stripped, types = {}, {}, {}

    if list then
        for child in list:iter_children() do
            local kind = child:type()

            if kind == "..." then
                written[#written + 1] = "..."
                stripped[#stripped + 1] = "..."
                types[#types + 1] = "..."
            elseif child:named() then
                local full = squash(text_of(child, buf))
                written[#written + 1] = full

                -- A default argument belongs to the declaration only; repeating
                -- it on the definition does not compile.
                local default = child:field("default_value")[1]

                if default then
                    local bare = squash(text_before(buf, child, default))
                    stripped[#stripped + 1] = squash((bare:gsub("=%s*$", "")))
                else
                    stripped[#stripped + 1] = full
                end

                types[#types + 1] = parameter_type(buf, child)
            end
        end
    end

    return {
        written = "(" .. table.concat(written, ", ") .. ")",
        stripped = "(" .. table.concat(stripped, ", ") .. ")",
        types = types,
        count = #types,
    }
end

---Everything the declarator carries after the parameter list: `const`,
---`noexcept`, a ref-qualifier, a trailing return type. `override` and `final`
---are pulled out separately -- they are legal on the declaration only.
---@param buf integer
---@param declarator TSNode
---@return string trailing
---@return string virtual_specifiers
local function trailing_of(buf, declarator)
    local list = declarator:field("parameters")[1]
    local after, virtual = {}, {}
    local seen = list == nil

    for child in declarator:iter_children() do
        if list and child:id() == list:id() then
            seen = true
        elseif seen then
            local part = squash(text_of(child, buf))

            if part ~= "" then
                if child:type() == "virtual_specifier" then
                    virtual[#virtual + 1] = part
                else
                    after[#after + 1] = part
                end
            end
        end
    end

    return table.concat(after, " "), table.concat(virtual, " ")
end

---Splits the text in front of the name into the specifiers that belong to one
---side only and the return type, which belongs to both.
---@param pre string
---@return string specifiers
---@return string return_type
---@return string[] specifier_list
local function split_specifiers(pre)
    local rest = squash(pre)
    local taken = {}

    while true do
        local word = rest:match("^([%a_][%w_]*)")

        if not word or not declaration_only_specifiers[word] then
            break
        end

        taken[#taken + 1] = word
        rest = squash(rest:sub(#word + 1))
    end

    local specifiers = table.concat(taken, " ")

    if specifiers ~= "" then
        specifiers = specifiers .. " "
    end

    if rest ~= "" then
        rest = rest .. " "
    end

    return specifiers, rest, taken
end

---@param node TSNode
---@return TSNode|nil
local function template_inner(node)
    for child in node:iter_children() do
        local kind = child:type()

        if function_nodes[kind] or class_nodes[kind] or kind == "friend_declaration" then
            return child
        end
    end

    return nil
end

---`<T, N>` for `template <typename T, int N>`, so an out-of-line definition of
---a class template member can name the class it belongs to.
---@param buf integer
---@param node TSNode template_declaration
---@return string
local function template_arguments(buf, node)
    local list = node:field("parameters")[1]

    if not list then
        return ""
    end

    local names = {}

    for child in list:iter_children() do
        if child:named() then
            local kind = child:type()
            local name

            if kind == "type_parameter_declaration" or kind == "variadic_type_parameter_declaration" then
                name = text_of(child:named_child(child:named_child_count() - 1), buf)

                if kind == "variadic_type_parameter_declaration" then
                    name = name .. "..."
                end
            else
                local declarator = child:field("declarator")[1]
                name = declarator and text_of(declarator, buf) or nil
            end

            if name and name ~= "" then
                names[#names + 1] = squash(name)
            end
        end
    end

    if #names == 0 then
        return ""
    end

    return "<" .. table.concat(names, ", ") .. ">"
end

---@param scope table[]
---@return string
local function qualifier_of(scope)
    local parts = {}

    for _, entry in ipairs(scope) do
        parts[#parts + 1] = entry.name .. (entry.args or "")
    end

    if #parts == 0 then
        return ""
    end

    return table.concat(parts, "::") .. "::"
end

---@param scope table[]
---@return string[]
local function scope_templates(scope)
    local headers = {}

    for _, entry in ipairs(scope) do
        if entry.template then
            headers[#headers + 1] = entry.template
        end
    end

    return headers
end

---@param buf integer
---@param scope table[]
---@param node TSNode
---@param wrapper TSNode|nil the template_declaration around `node`, if any
---@return table[]
local function extend_scope(buf, scope, node, wrapper)
    local kind = node:type()
    local entry

    if class_nodes[kind] then
        local name = node:field("name")[1]

        if not name then
            return scope
        end

        entry = { name = squash(text_of(name, buf)), class = true }

        if wrapper then
            entry.args = template_arguments(buf, wrapper)
            entry.template = squash(text_before(buf, wrapper, node))
        end
    elseif kind == "namespace_definition" then
        local name = node:field("name")[1]

        -- An anonymous namespace cannot be named from the outside, so nothing
        -- is added to the qualifier.
        if not name then
            return scope
        end

        entry = { name = squash(text_of(name, buf)) }
    else
        return scope
    end

    local extended = vim.list_extend({}, scope)
    extended[#extended + 1] = entry

    return extended
end

---@param buf integer
---@param node TSNode declaration | field_declaration | function_definition | template_declaration
---@param scope table[]
---@return table|nil
local function build_model(buf, node, scope)
    local inner = node
    local template = nil

    if node:type() == "template_declaration" then
        inner = template_inner(node)

        if not inner then
            return nil
        end

        template = squash(text_before(buf, node, inner))
    end

    -- A friend is declared inside a class but is not a member of it.
    local parent = inner:parent()
    local is_friend = parent ~= nil and parent:type() == "friend_declaration"

    local declarator = find_function_declarator(inner)

    if not declarator then
        return nil
    end

    local name_node = declarator:field("declarator")[1]

    if not name_node then
        return nil
    end

    -- An out-of-line definition names itself `ns::Class::f`; that qualifier is
    -- part of the written text, not of the enclosing scope.
    local written_qualifier = ""
    local base = name_node

    while base:type() == "qualified_identifier" do
        local scope_node = base:field("scope")[1]
        written_qualifier = written_qualifier .. squash(text_of(scope_node, buf)) .. "::"
        local next_node = base:field("name")[1]

        if not next_node then
            break
        end

        base = next_node
    end

    local params = parameters(buf, declarator:field("parameters")[1])
    local trailing, virtual_specifier = trailing_of(buf, declarator)
    local pre = text_before(buf, inner, name_node)
    local specifiers, return_type, specifier_list = split_specifiers(pre)

    local body = inner:field("body")[1]
    local default_value = inner:field("default_value")[1]
    local deleted, defaulted = false, false

    for child in inner:iter_children() do
        local kind = child:type()

        if kind == "delete_method_clause" then
            deleted = true
        elseif kind == "default_method_clause" then
            defaulted = true
        end
    end

    local default_text = default_value and squash(text_of(default_value, buf)) or ""
    deleted = deleted or default_text == "delete"
    defaulted = defaulted or default_text == "default"

    local srow, scol = inner:start()
    local erow, ecol = declarator:end_()
    local nrow, nscol, nerow, necol = node:range()

    local own_scope = scope

    if is_friend then
        -- Keep the namespaces the friend is declared in, drop the class.
        own_scope = {}

        for _, entry in ipairs(scope) do
            if not entry.class then
                own_scope[#own_scope + 1] = entry
            end
        end
    end

    local innermost = own_scope[#own_scope]

    return {
        buf = buf,
        node = node,
        inner = inner,
        declarator = declarator,
        name = squash(text_of(base, buf)),
        written_qualifier = written_qualifier,
        scope_qualifier = qualifier_of(own_scope),
        scope_templates = scope_templates(own_scope),
        specifiers = specifiers,
        specifier_list = specifier_list,
        member = innermost ~= nil and innermost.class == true,
        return_type = return_type,
        params = params,
        trailing = trailing,
        virtual_specifier = virtual_specifier,
        template = (template ~= nil and template ~= "") and template or nil,
        pure = default_text == "0",
        deleted = deleted,
        defaulted = defaulted,
        has_body = body ~= nil,
        kind = body ~= nil and "definition" or "declaration",
        friend = is_friend,
        class_node = nil,
        indent = (vim.api.nvim_buf_get_lines(buf, srow, srow + 1, false)[1] or ""):match("^%s*") or "",
        signature_range = { srow, scol, erow, ecol },
        range = { nrow, nscol, nerow, necol },
    }
end

---@param buf integer
---@param node TSNode
---@param scope table[]
---@param class_node TSNode|nil
---@param out table[]
local function walk(buf, node, scope, class_node, out)
    for child in node:iter_children() do
        local kind = child:type()

        if kind == "template_declaration" then
            local inner = template_inner(child)
            local inner_kind = inner and inner:type() or ""

            if class_nodes[inner_kind] then
                walk(buf, inner, extend_scope(buf, scope, inner, child), inner, out)
            elseif inner then
                local model = build_model(buf, child, scope)

                if model then
                    model.class_node = class_node
                    out[#out + 1] = model
                end
            end
        elseif function_nodes[kind] then
            local model = build_model(buf, child, scope)

            if model then
                model.class_node = class_node
                out[#out + 1] = model
            else
                -- `struct A { ... } a;` and friends: the declaration is not a
                -- function but may hold one.
                walk(buf, child, scope, class_node, out)
            end
        elseif containers[kind] then
            local next_class = class_nodes[kind] and child or class_node
            walk(buf, child, extend_scope(buf, scope, child, nil), next_class, out)
        end
    end
end

---Every function declaration and definition in `buf`, outermost first.
---@param buf integer
---@return table[]
function M.functions(buf)
    local root = root_of(buf)

    if not root then
        return {}
    end

    local out = {}
    walk(buf, root, {}, nil, out)

    return out
end

---The innermost function whose text covers `row` (0-based).
---@param buf integer
---@param row integer
---@return table|nil
function M.function_at(buf, row)
    local best

    for _, model in ipairs(M.functions(buf)) do
        if row >= model.range[1] and row <= model.range[3] then
            if not best or (model.range[3] - model.range[1]) < (best.range[3] - best.range[1]) then
                best = model
            end
        end
    end

    return best
end

---@param model table
---@return string
local function full_name(model)
    return model.scope_qualifier .. model.written_qualifier .. model.name
end

---`ns::A::f` matches `A::f` when the definition sits inside `namespace ns`.
---@param a string
---@param b string
---@return boolean
local function names_match(a, b)
    if a == b then
        return true
    end

    return a:sub(-(#b + 2)) == "::" .. b or b:sub(-(#a + 2)) == "::" .. a
end

--- Paths -------------------------------------------------------------------

---@param path string
---@return string
local function extension_of(path)
    return vim.fn.fnamemodify(path, ":e"):lower()
end

---@param path string
---@return boolean
function M.is_header(path)
    return header_extensions[extension_of(path)] == true
end

---@param dir string
---@return string[]
local function sibling_directories(dir)
    local parts = vim.split(vim.fs.normalize(dir), "/", { plain = true })
    local out = {}

    for index = #parts, 1, -1 do
        local part = parts[index]:lower()

        for _, pair in ipairs(directory_pairs) do
            local swapped

            if part == pair[1] then
                swapped = pair[2]
            elseif part == pair[2] then
                swapped = pair[1]
            end

            if swapped then
                local copy = vim.list_extend({}, parts)
                copy[index] = swapped
                out[#out + 1] = table.concat(copy, "/")

                -- `include/app/thing.h` is just as often `src/thing.cpp` as it
                -- is `src/app/thing.cpp`, so the shallower path is a candidate
                -- too -- the sub-directories under `include` usually exist only
                -- to give the `#include` a prefix.
                if index < #parts then
                    out[#out + 1] = table.concat(vim.list_slice(copy, 1, index), "/")
                end
            end
        end
    end

    return out
end

---The file on the other side of the header/source split, if it exists.
---@param path string
---@return string|nil
function M.counterpart(path)
    if not path or path == "" then
        return nil
    end

    path = vim.fs.normalize(path)
    local candidates = source_for[extension_of(path)] or header_for[extension_of(path)]

    if not candidates then
        return nil
    end

    local stem = vim.fn.fnamemodify(path, ":t:r")
    local directory = vim.fs.normalize(vim.fn.fnamemodify(path, ":h"))
    local directories = { directory }
    vim.list_extend(directories, sibling_directories(directory))

    local names = {}

    for _, candidate in ipairs(candidates) do
        names[#names + 1] = stem .. "." .. candidate
    end

    for _, candidate_directory in ipairs(directories) do
        for _, name in ipairs(names) do
            local guess = vim.fs.joinpath(candidate_directory, name)

            if vim.fn.filereadable(guess) == 1 then
                return guess
            end
        end
    end

    -- `src/thing.cpp` belongs to `include/<anything>/thing.h`: the sub-path
    -- under `include` exists to prefix the `#include` and cannot be guessed,
    -- so the swapped directory is searched for the file by name.
    for _, candidate_directory in ipairs(directories) do
        if candidate_directory ~= directory and vim.fn.isdirectory(candidate_directory) == 1 then
            local found = vim.fs.find(names, { path = candidate_directory, type = "file", limit = 1 })[1]

            if found then
                return vim.fs.normalize(found)
            end
        end
    end

    return nil
end

---clangd knows the real answer -- it reads the compilation database -- so ask
---it first when it is attached, and fall back to the layout guesses above.
---@param buf integer
---@return string|nil
function M.counterpart_for_buffer(buf)
    local path = vim.api.nvim_buf_get_name(buf)

    for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, name = "clangd" })) do
        local ok, response = pcall(function()
            return client:request_sync("textDocument/switchSourceHeader", {
                uri = vim.uri_from_bufnr(buf),
            }, 1000, buf)
        end)

        if ok and response and response.result then
            local other = vim.uri_to_fname(response.result)

            if vim.fn.filereadable(other) == 1 then
                return vim.fs.normalize(other)
            end
        end
    end

    return M.counterpart(path)
end

---Where a source file created for `header` should live, and what it should
---include. `include/proj/thing.h` is included as `proj/thing.h`, which is how
---such a project is meant to be compiled.
---@param header string
---@return string path
---@return string include
function M.new_source_for(header)
    header = vim.fs.normalize(header)
    local directory = vim.fn.fnamemodify(header, ":h")
    local stem = vim.fn.fnamemodify(header, ":t:r")
    local file = vim.fn.fnamemodify(header, ":t")
    local include = file

    local parts = vim.split(directory, "/", { plain = true })

    for index = #parts, 1, -1 do
        local part = parts[index]:lower()

        if part == "include" or part == "inc" or part == "headers" then
            local below = table.concat(vim.list_slice(parts, index + 1, #parts), "/")
            include = below == "" and file or (below .. "/" .. file)

            for _, sibling in ipairs(sibling_directories(directory)) do
                if vim.fn.isdirectory(vim.fn.fnamemodify(sibling, ":h")) == 1 then
                    directory = sibling
                    break
                end
            end

            break
        end
    end

    return vim.fs.joinpath(directory, stem .. ".cpp"), include
end

---@param path string
---@return integer
local function load_buffer(path)
    local buf = vim.fn.bufadd(path)
    vim.fn.bufload(buf)

    return buf
end

--- Rendering ---------------------------------------------------------------

---`{` on its own line or at the end of the signature, whichever the target
---file already does. `vim.g.cpp_brace_style` overrides the guess.
---@param buf integer
---@return "attach"|"next_line"
local function brace_style(buf)
    local forced = vim.g.cpp_brace_style

    if forced == "attach" or forced == "next_line" then
        return forced
    end

    local attached, own_line = 0, 0

    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line:match("%)%s*[%w_:%s]*{%s*$") then
            attached = attached + 1
        elseif line:match("^%s*{%s*$") then
            own_line = own_line + 1
        end
    end

    return own_line > attached and "next_line" or "attach"
end

---Which of the declaration's leading specifiers the definition may repeat.
---`static` is illegal on the out-of-line definition of a member but is how a
---file-scope function keeps its internal linkage; `inline` only means anything
---while the definition stays in the same file as the declaration.
---@param model table
---@param same_file boolean
---@return string
local function definition_specifiers(model, same_file)
    local kept = {}

    for _, word in ipairs(model.specifier_list or {}) do
        if (word == "static" and not model.member) or (word == "inline" and same_file) then
            kept[#kept + 1] = word
        end
    end

    if #kept == 0 then
        return ""
    end

    return table.concat(kept, " ") .. " "
end

---The lines of the out-of-line definition for `model`.
---@param model table
---@param opts { indent: string, brace: string, same_file: boolean }
---@return string[] lines
---@return integer body_offset index of the empty line inside the body
local function definition_lines(model, opts)
    local lines = {}

    for _, header in ipairs(model.scope_templates) do
        lines[#lines + 1] = header
    end

    if model.template then
        lines[#lines + 1] = model.template
    end

    local head = definition_specifiers(model, opts.same_file)
        .. model.return_type
        .. model.scope_qualifier
        .. model.written_qualifier
        .. model.name
        .. model.params.stripped

    if model.trailing ~= "" then
        head = head .. " " .. model.trailing
    end

    if opts.brace == "next_line" then
        lines[#lines + 1] = head
        lines[#lines + 1] = "{"
    else
        lines[#lines + 1] = head .. " {"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "}"

    local body_offset = #lines - 2

    if opts.indent ~= "" then
        for index, line in ipairs(lines) do
            if line ~= "" then
                lines[index] = opts.indent .. line
            end
        end
    end

    return lines, body_offset
end

--- Implementing ------------------------------------------------------------

---@param buf integer
---@param model table
---@return boolean
local function already_defined(buf, model)
    local name = full_name(model)

    for _, candidate in ipairs(M.functions(buf)) do
        if
            candidate.kind == "definition"
            and candidate.name == model.name
            and names_match(full_name(candidate), name)
            and candidate.params.count == model.params.count
        then
            return true
        end
    end

    return false
end

---Definitions of the same class belong next to each other, so a new one goes
---after the last definition that shares its qualifier; otherwise at the end.
---@param buf integer
---@param model table
---@return integer row 0-based row to insert at
local function insertion_row(buf, model)
    local qualifier = model.scope_qualifier .. model.written_qualifier
    local row = vim.api.nvim_buf_line_count(buf)

    if qualifier ~= "" then
        for _, candidate in ipairs(M.functions(buf)) do
            local candidate_qualifier = candidate.scope_qualifier .. candidate.written_qualifier

            if candidate.kind == "definition" and candidate_qualifier == qualifier then
                row = candidate.range[3] + 1
            end
        end
    end

    return row
end

---@param model table
---@return integer|nil
local function target_buffer(model)
    local buf = model.buf
    local path = vim.api.nvim_buf_get_name(buf)

    -- A template has to be visible wherever it is instantiated, so its
    -- definition stays in the header next to the declaration.
    if model.template or #model.scope_templates > 0 then
        return buf
    end

    if path == "" or not M.is_header(path) then
        return buf
    end

    local counterpart = M.counterpart_for_buffer(buf)

    if counterpart then
        return load_buffer(counterpart)
    end

    local source, include = M.new_source_for(path)
    local directory = vim.fn.fnamemodify(source, ":h")

    if vim.fn.isdirectory(directory) == 0 then
        vim.fn.mkdir(directory, "p")
    end

    local created = load_buffer(source)
    vim.api.nvim_buf_set_lines(created, 0, -1, false, { ('#include "%s"'):format(include), "" })
    -- A file that exists is easier to reason about than an unnamed new buffer
    -- that a stray `:q!` would take with it. `noautocmd` keeps format-on-save
    -- away from a file the user has not looked at yet.
    vim.api.nvim_buf_call(created, function()
        vim.cmd("noautocmd silent keepalt write")
    end)

    vim.notify("Created " .. vim.fn.fnamemodify(source, ":."), vim.log.levels.INFO)

    return created
end

---Row (0-based) just past the class `model` is declared in, used when a
---template definition has to stay in the header.
---@param model table
---@return integer|nil
local function after_class_row(model)
    local node = model.class_node

    if not node then
        return nil
    end

    local parent = node:parent()

    if parent and parent:type() == "template_declaration" then
        node = parent
    end

    local row = node:end_()
    local line = vim.api.nvim_buf_get_lines(model.buf, row, row + 1, false)[1] or ""

    -- `class A { ... };` ends on the `}` of the body; the `;` that follows is
    -- part of the surrounding declaration, so step past that line too.
    if line:match("^%s*}%s*;") or line:match("}%s*;%s*$") then
        row = row + 1
    end

    return row
end

---@param models table[]
---@return integer written
local function write_definitions(models)
    local skipped = {}
    local inserted = 0
    local jump

    for _, model in ipairs(models) do
        local reason

        if model.has_body then
            reason = "already defined"
        elseif model.pure then
            reason = "pure virtual"
        elseif model.deleted then
            reason = "deleted"
        elseif model.defaulted then
            reason = "defaulted"
        end

        local target = not reason and target_buffer(model) or nil

        if not reason and not target then
            reason = "no target file"
        end

        if not reason and already_defined(target, model) then
            reason = "already defined"
        end

        if reason then
            skipped[#skipped + 1] = ("%s (%s)"):format(model.name, reason)
        else
            local same_file = target == model.buf
            local row
            local indent = ""

            if same_file and (model.template or #model.scope_templates > 0) then
                row = after_class_row(model) or vim.api.nvim_buf_line_count(target)
                indent = model.indent:sub(1, 0)
            else
                row = insertion_row(target, model)
            end

            local lines, body_offset = definition_lines(model, {
                indent = indent,
                brace = brace_style(target),
                same_file = same_file,
            })

            local previous = vim.api.nvim_buf_get_lines(target, math.max(row - 1, 0), row, false)[1]

            if previous and squash(previous) ~= "" then
                table.insert(lines, 1, "")
                body_offset = body_offset + 1
            end

            vim.api.nvim_buf_set_lines(target, row, row, false, lines)
            inserted = inserted + 1

            if not jump then
                jump = { buf = target, row = row + body_offset }
            end
        end
    end

    if jump then
        if jump.buf ~= vim.api.nvim_get_current_buf() then
            vim.cmd.edit(vim.fn.fnameescape(vim.api.nvim_buf_get_name(jump.buf)))
        end

        pcall(vim.api.nvim_win_set_cursor, 0, { jump.row + 1, 0 })

        local where = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(jump.buf), ":t")
        vim.notify(("Defined %d function%s in %s"):format(inserted, inserted == 1 and "" or "s", where))
    end

    if #skipped > 0 then
        vim.notify("Skipped " .. table.concat(skipped, ", "), vim.log.levels.WARN)
    end

    return inserted
end

---Write the definition for the declaration under the cursor, or for every
---declaration in the given line range.
---@param opts { line1: integer?, line2: integer?, range: integer? }|nil
function M.implement(opts)
    opts = opts or {}
    local buf = vim.api.nvim_get_current_buf()

    if not root_of(buf) then
        vim.notify("The C++ parser is not available for this buffer", vim.log.levels.WARN)
        return
    end

    local models = {}

    if opts.range and opts.range > 0 then
        local first, last = opts.line1 - 1, opts.line2 - 1

        for _, model in ipairs(M.functions(buf)) do
            if model.range[1] >= first and model.range[1] <= last then
                models[#models + 1] = model
            end
        end
    else
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        local model = M.function_at(buf, row)

        if model then
            models[1] = model
        end
    end

    if #models == 0 then
        vim.notify("No function declaration here", vim.log.levels.WARN)
        return
    end

    write_definitions(models)
end

---Write the definitions for every declaration of the class under the cursor,
---or of the whole file when the cursor is not inside a class.
function M.implement_all()
    local buf = vim.api.nvim_get_current_buf()

    if not root_of(buf) then
        vim.notify("The C++ parser is not available for this buffer", vim.log.levels.WARN)
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local functions = M.functions(buf)
    local here = M.function_at(buf, row)
    local class_node = here and here.class_node or nil

    if not class_node then
        for _, model in ipairs(functions) do
            if model.class_node and row >= model.class_node:start() and row <= model.class_node:end_() then
                class_node = model.class_node
                break
            end
        end
    end

    local models = {}

    for _, model in ipairs(functions) do
        local in_scope

        if class_node then
            in_scope = model.class_node ~= nil and model.class_node:id() == class_node:id()
        else
            in_scope = model.class_node == nil
        end

        if
            in_scope
            and model.kind == "declaration"
            and not model.pure
            and not model.deleted
            and not model.defaulted
        then
            models[#models + 1] = model
        end
    end

    if #models == 0 then
        vim.notify("Nothing left to define here", vim.log.levels.INFO)
        return
    end

    write_definitions(models)
end

--- Changing a signature ----------------------------------------------------

---The declaration for a definition, or the definition for a declaration.
---@param model table
---@return table|nil
function M.counterpart_function(model)
    local wanted = model.kind == "definition" and "declaration" or "definition"
    local name = full_name(model)

    local function search(buf)
        local fallback

        for _, candidate in ipairs(M.functions(buf)) do
            if
                candidate.kind == wanted
                and candidate.name == model.name
                and names_match(full_name(candidate), name)
                and candidate.params.count == model.params.count
            then
                if table.concat(candidate.params.types, ",") == table.concat(model.params.types, ",") then
                    return candidate
                end

                fallback = fallback or candidate
            end
        end

        return fallback
    end

    -- A header-only class, or a static function declared at the top of its own
    -- .cpp, has both sides in one file.
    local here = search(model.buf)

    if here then
        return here
    end

    local counterpart = M.counterpart_for_buffer(model.buf)

    if not counterpart then
        return nil
    end

    local buf = load_buffer(counterpart)

    if buf == model.buf then
        return nil
    end

    return search(buf)
end

---@param buf integer
---@param range integer[]
---@param text string
local function replace_range(buf, range, text)
    vim.api.nvim_buf_set_text(buf, range[1], range[2], range[3], range[4], vim.split(text, "\n", { plain = true }))
end

---Parse a hand-typed signature the same way a real one is parsed, by putting
---it in a scratch buffer -- every helper here works on buffers.
---@param text string
---@return table|nil
function M.parse_signature(text)
    text = squash(text)

    if text == "" then
        return nil
    end

    if not text:match(";$") then
        text = text .. ";"
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })

    local model = M.functions(buf)[1]

    if model then
        -- Detach from the scratch buffer: only the strings are used from here.
        model.buf = nil
        model.node = nil
        model.inner = nil
        model.declarator = nil
        model.class_node = nil
    end

    vim.api.nvim_buf_delete(buf, { force = true })

    return model
end

---What the other side should read once `updated` replaces `model`. Each side
---keeps its own specifiers, its own `Class::` qualifier and its own
---`override`; the return type, the name, the parameters and the cv/noexcept
---qualifiers are what gets copied across.
---@param other table
---@param updated table
---@return string
local function rewritten(other, updated)
    local params = other.kind == "definition" and updated.params.stripped or updated.params.written
    local text = other.specifiers .. updated.return_type .. other.written_qualifier .. updated.name .. params
    local trailing = updated.trailing

    if other.virtual_specifier ~= "" then
        trailing = trailing == "" and other.virtual_specifier or (trailing .. " " .. other.virtual_specifier)
    end

    if trailing ~= "" then
        text = text .. " " .. trailing
    end

    return text
end

---Edit the signature under the cursor and apply the same change to the
---declaration or definition on the other side.
function M.change_signature()
    local buf = vim.api.nvim_get_current_buf()

    if not root_of(buf) then
        vim.notify("The C++ parser is not available for this buffer", vim.log.levels.WARN)
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local model = M.function_at(buf, row)

    if not model then
        vim.notify("No function here", vim.log.levels.WARN)
        return
    end

    local range = model.signature_range
    local current = squash(range_text(buf, range[1], range[2], range[3], range[4]))

    vim.ui.input({ prompt = "Signature: ", default = current }, function(input)
        if not input or squash(input) == "" or squash(input) == current then
            return
        end

        M.apply_signature(model, input)
    end)
end

---@param model table the function as it is now
---@param text string the signature as the user typed it
---@return boolean
function M.apply_signature(model, text)
    local updated = M.parse_signature(text)

    if not updated then
        vim.notify("Could not parse that signature", vim.log.levels.ERROR)
        return false
    end

    -- Find the other side before editing: it is matched on the old name and
    -- parameter types, which are about to change here.
    local other = M.counterpart_function(model)
    local other_modified = other ~= nil and vim.bo[other.buf].modified or false

    replace_range(model.buf, model.signature_range, squash(text))

    if not other then
        vim.notify(("Updated the %s only; the other side was not found"):format(model.kind), vim.log.levels.WARN)
        return true
    end

    replace_range(other.buf, other.signature_range, rewritten(other, updated))

    local path = vim.api.nvim_buf_get_name(other.buf)

    if other.buf ~= model.buf and not other_modified and path ~= "" then
        -- The other file is usually not on screen, and an unsaved hidden
        -- buffer is easy to lose. `noautocmd` keeps format-on-save from
        -- rewriting a file the user has not opened.
        vim.api.nvim_buf_call(other.buf, function()
            vim.cmd("noautocmd silent keepalt write")
        end)
    end

    vim.notify(("Updated the %s in %s"):format(other.kind, vim.fn.fnamemodify(path, ":t")))

    return true
end

function M.setup()
    vim.api.nvim_create_user_command("CppImplement", function(command)
        M.implement({ line1 = command.line1, line2 = command.line2, range = command.range })
    end, { range = true, desc = "Write the definition for the declaration under the cursor" })

    vim.api.nvim_create_user_command("CppImplementAll", function()
        M.implement_all()
    end, { desc = "Write the definitions missing from the class under the cursor" })

    vim.api.nvim_create_user_command("CppSignature", function()
        M.change_signature()
    end, { desc = "Change a function signature on both sides" })
end

return M
