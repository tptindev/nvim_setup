-- Definition generation and signature changes for C++ (config/cpp.lua).
--
-- The `cpp` parser is not bundled with Neovim, but nvim-treesitter installs it
-- under `stdpath("data")/site`, which stays on the runtimepath even with
-- `-u NONE` -- so this test drives the real tree rather than a stand-in.
local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)))
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message)
    end
end

local script_path = vim.fs.normalize(debug.getinfo(1, "S").source:sub(2))
local config_root = vim.fs.dirname(vim.fs.dirname(script_path))

package.path = table.concat({
    vim.fs.joinpath(config_root, "lua", "?.lua"),
    vim.fs.joinpath(config_root, "lua", "?", "init.lua"),
    package.path,
}, ";")

if not pcall(vim.treesitter.language.add, "cpp") then
    print("skipped: the cpp Treesitter parser is not installed")
    vim.cmd("qa!")
    return
end

local cpp = require("config.cpp")

local notifications = {}
vim.notify = function(message)
    notifications[#notifications + 1] = message
end

local root = vim.fs.normalize(vim.fn.tempname())
vim.fn.mkdir(vim.fs.joinpath(root, "include", "app"), "p")
vim.fn.mkdir(vim.fs.joinpath(root, "src"), "p")

local header_path = vim.fs.joinpath(root, "include", "app", "widget.h")
local source_path = vim.fs.joinpath(root, "src", "widget.cpp")

local function write(path, lines)
    vim.fn.writefile(lines, path)
end

local function lines_of(path)
    local buf = vim.fn.bufadd(path)
    vim.fn.bufload(buf)

    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function text_of(path)
    return table.concat(lines_of(path), "\n")
end

local function reset()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end

    notifications = {}
end

write(header_path, {
    "#pragma once",
    "",
    "#include <string>",
    "",
    "namespace app {",
    "",
    "class Widget {",
    "public:",
    "  explicit Widget(int id);",
    "  virtual ~Widget();",
    "",
    "  virtual int Draw(const std::string& label, bool flush = true) const noexcept override;",
    "  static bool Ready();",
    "  void Inline() {}",
    "  virtual void Pure() = 0;",
    "  Widget& operator=(const Widget&) = delete;",
    "",
    "  template <typename T>",
    "  void Emit(T value);",
    "};",
    "",
    "}  // namespace app",
})

write(source_path, {
    '#include "app/widget.h"',
})

--- Counterpart resolution ---------------------------------------------------

assert_equal(cpp.counterpart(header_path), source_path, "expected include/app/*.h to pair with src/*.cpp")
assert_equal(cpp.counterpart(source_path), header_path, "expected src/*.cpp to pair back with the header")
assert_truthy(cpp.is_header(header_path), "expected .h to be recognised as a header")
assert_truthy(not cpp.is_header(source_path), "expected .cpp not to be recognised as a header")

local flat_dir = vim.fs.joinpath(root, "flat")
vim.fn.mkdir(flat_dir, "p")
write(vim.fs.joinpath(flat_dir, "thing.hpp"), { "void thing();" })
write(vim.fs.joinpath(flat_dir, "thing.cpp"), { '#include "thing.hpp"' })
assert_equal(
    cpp.counterpart(vim.fs.joinpath(flat_dir, "thing.hpp")),
    vim.fs.joinpath(flat_dir, "thing.cpp"),
    "expected a header to pair with the source next to it"
)

--- The parsed model --------------------------------------------------------

reset()
vim.cmd.edit(vim.fn.fnameescape(header_path))
local header_buf = vim.api.nvim_get_current_buf()

local functions = cpp.functions(header_buf)
local by_name = {}

for _, model in ipairs(functions) do
    by_name[model.name] = model
end

assert_truthy(by_name["Draw"], "expected Draw to be found in the header")
assert_equal(by_name["Draw"].scope_qualifier, "app::Widget::", "expected the namespace and class to qualify Draw")
assert_equal(by_name["Draw"].specifiers, "virtual ", "expected `virtual` to be held apart from the return type")
assert_equal(by_name["Draw"].return_type, "int ", "expected the return type without the specifiers")
assert_equal(by_name["Draw"].trailing, "const noexcept", "expected cv and noexcept qualifiers to be kept")
assert_equal(by_name["Draw"].virtual_specifier, "override", "expected `override` to be held apart")
assert_equal(
    by_name["Draw"].params.stripped,
    "(const std::string& label, bool flush)",
    "expected default arguments to be dropped from the definition form"
)
assert_equal(
    by_name["Draw"].params.written,
    "(const std::string& label, bool flush = true)",
    "expected the declaration form to keep default arguments"
)
assert_truthy(by_name["Pure"].pure, "expected `= 0` to mark a pure virtual")
assert_truthy(by_name["operator="].deleted, "expected `= delete` to be detected")
assert_truthy(by_name["Inline"].has_body, "expected an in-class body to count as a definition")
assert_equal(by_name["~Widget"].name, "~Widget", "expected the destructor name to include the tilde")
assert_equal(by_name["Widget"].specifiers, "explicit ", "expected `explicit` to be held apart")

--- Implementing one declaration ---------------------------------------------

local function goto_declaration(name)
    local model = nil

    for _, candidate in ipairs(cpp.functions(vim.api.nvim_get_current_buf())) do
        if candidate.name == name then
            model = candidate
        end
    end

    assert_truthy(model, "expected to find a declaration for " .. name)
    vim.api.nvim_win_set_cursor(0, { model.range[1] + 1, 0 })
end

goto_declaration("Draw")
cpp.implement()

assert_equal(
    vim.api.nvim_buf_get_name(0),
    source_path,
    "expected the source file to be opened after writing the definition"
)

local source_text = text_of(source_path)
assert_truthy(
    source_text:find("int app::Widget::Draw(const std::string& label, bool flush) const noexcept {", 1, true),
    "expected the generated definition to be qualified, stripped of `virtual`/`override` and of default arguments:\n"
        .. source_text
)
assert_truthy(not source_text:find("override", 1, true), "expected `override` to stay out of the definition")
assert_truthy(not source_text:find("virtual", 1, true), "expected `virtual` to stay out of the definition")

local row = vim.api.nvim_win_get_cursor(0)[1]
assert_equal(
    vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1],
    "",
    "expected the cursor to land on the empty line inside the new body"
)

-- A second run must not write the definition twice.
vim.cmd.edit(vim.fn.fnameescape(header_path))
goto_declaration("Draw")
notifications = {}
cpp.implement()
local _, occurrences = text_of(source_path):gsub("Widget::Draw", "")
assert_equal(occurrences, 1, "expected an existing definition to be left alone")
assert_truthy(
    table.concat(notifications, " "):find("already defined", 1, true),
    "expected a skip to be reported: " .. vim.inspect(notifications)
)

--- Implementing a whole class ------------------------------------------------

reset()
vim.cmd.edit(vim.fn.fnameescape(header_path))
goto_declaration("Ready")
cpp.implement_all()

source_text = text_of(source_path)

for _, expected in ipairs({
    "app::Widget::Widget(int id) {",
    "app::Widget::~Widget() {",
    "bool app::Widget::Ready() {",
}) do
    assert_truthy(source_text:find(expected, 1, true), ("expected %q in:\n%s"):format(expected, source_text))
end

assert_truthy(not source_text:find("Pure", 1, true), "expected a pure virtual to be skipped")
assert_truthy(not source_text:find("operator=", 1, true), "expected a deleted function to be skipped")
assert_truthy(not source_text:find("Inline", 1, true), "expected a function with a body to be skipped")
assert_truthy(not source_text:find("Emit", 1, true), "expected a template member to stay out of the source file")
assert_truthy(not source_text:find("explicit", 1, true), "expected `explicit` to stay out of the definition")
assert_truthy(not source_text:find("static", 1, true), "expected `static` to stay out of the definition")

--- Templates stay in the header ----------------------------------------------

reset()
vim.cmd.edit(vim.fn.fnameescape(header_path))
goto_declaration("Emit")
cpp.implement()

assert_equal(
    vim.api.nvim_buf_get_name(0),
    header_path,
    "expected a template member to be defined in the header, not in the source file"
)

local header_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert_truthy(
    header_text:find("template <typename T>\nvoid app::Widget::Emit(T value) {", 1, true),
    "expected the template header to be repeated above the definition:\n" .. header_text
)

local class_end = header_text:find("};", 1, true)
assert_truthy(
    class_end and header_text:find("void app::Widget::Emit", class_end, true),
    "expected the template definition to be placed after the class body"
)

--- Changing a signature ------------------------------------------------------

reset()
write(header_path, {
    "#pragma once",
    "",
    "#include <string>",
    "",
    "namespace app {",
    "",
    "class Widget {",
    "public:",
    "  virtual int Draw(const std::string& label, bool flush = true) const override;",
    "};",
    "",
    "}  // namespace app",
})

write(source_path, {
    '#include "app/widget.h"',
    "",
    "int app::Widget::Draw(const std::string& label, bool flush) const {",
    "  return 0;",
    "}",
})

vim.cmd.edit(vim.fn.fnameescape(header_path))
local declaration = cpp.function_at(vim.api.nvim_get_current_buf(), 8)
assert_truthy(declaration, "expected to find the declaration to edit")
assert_equal(declaration.kind, "declaration", "expected the header side to be a declaration")

assert_truthy(
    cpp.apply_signature(declaration, "virtual bool Draw(const std::string& label, int repeat = 1) const override"),
    "expected the signature change to be applied"
)

header_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert_truthy(
    header_text:find("virtual bool Draw(const std::string& label, int repeat = 1) const override;", 1, true),
    "expected the declaration to read back exactly as typed:\n" .. header_text
)

source_text = text_of(source_path)
assert_truthy(
    source_text:find("bool app::Widget::Draw(const std::string& label, int repeat) const {", 1, true),
    "expected the definition to follow, without `virtual`, `override` or the default argument:\n" .. source_text
)
assert_truthy(source_text:find("return 0;", 1, true), "expected the body to be left untouched")

--- ...and from the definition side --------------------------------------------

reset()
vim.cmd.edit(vim.fn.fnameescape(source_path))
vim.api.nvim_win_set_cursor(0, { 3, 0 })
local definition = cpp.function_at(vim.api.nvim_get_current_buf(), 2)
assert_truthy(definition, "expected to find the definition to edit")
assert_equal(definition.kind, "definition", "expected the source side to be a definition")

local asked
vim.ui.input = function(opts, callback)
    asked = opts.default
    callback("bool app::Widget::Draw(const std::string& label, int repeat, bool flush) const")
end

cpp.change_signature()

assert_equal(
    asked,
    "bool app::Widget::Draw(const std::string& label, int repeat) const",
    "expected the prompt to be pre-filled with the current signature"
)

source_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert_truthy(
    source_text:find("bool app::Widget::Draw(const std::string& label, int repeat, bool flush) const {", 1, true),
    "expected the definition to read back as typed:\n" .. source_text
)

header_text = text_of(header_path)
assert_truthy(
    header_text:find("virtual bool Draw(const std::string& label, int repeat, bool flush) const override;", 1, true),
    "expected the declaration to keep `virtual`/`override` and take the new parameters:\n" .. header_text
)

--- Commands ------------------------------------------------------------------

cpp.setup()

for _, command in ipairs({ "CppImplement", "CppImplementAll", "CppSignature" }) do
    assert_truthy(vim.fn.exists(":" .. command) > 0, "expected :" .. command .. " to be defined by setup()")
end

--- Overloads and the ranged command -------------------------------------------

reset()
local overload_header = vim.fs.joinpath(root, "over.h")
local overload_source = vim.fs.joinpath(root, "over.cpp")

write(overload_header, {
    "#pragma once",
    "",
    "namespace a::b {",
    "",
    "struct Thing {",
    "  void Set(int value);",
    "  void Set(double value, bool round);",
    "  void Keep();",
    "};",
    "",
    "}",
})

write(overload_source, {
    '#include "over.h"',
    "",
    "namespace a::b {",
    "",
    "void Thing::Set(int value) {",
    "}",
    "",
    "void Thing::Set(double value, bool round) {",
    "}",
    "",
    "}",
})

vim.cmd.edit(vim.fn.fnameescape(overload_header))
local two_parameters

for _, model in ipairs(cpp.functions(0)) do
    if model.name == "Set" and model.params.count == 2 then
        two_parameters = model
    end
end

assert_truthy(two_parameters, "expected to find the two-parameter overload")
cpp.apply_signature(two_parameters, "void Set(double value, int digits)")

source_text = text_of(overload_source)
assert_truthy(
    source_text:find("void Thing::Set(int value) {", 1, true),
    "expected the other overload to be left alone:\n" .. source_text
)
assert_truthy(
    source_text:find("void Thing::Set(double value, int digits) {", 1, true),
    "expected the matching overload to be updated, across a `namespace a::b` the definition sits inside:\n"
        .. source_text
)

-- `:CppImplement` over a range defines every declaration that starts in it.
reset()
local ranged_header = vim.fs.joinpath(root, "range.h")
local ranged_source = vim.fs.joinpath(root, "range.cpp")

write(ranged_header, {
    "#pragma once",
    "",
    "struct Thing {",
    "  void A();",
    "  void B(int x);",
    "  void C();",
    "};",
})

write(ranged_source, { '#include "range.h"' })

vim.cmd.edit(vim.fn.fnameescape(ranged_header))
vim.cmd("4,5CppImplement")

source_text = text_of(ranged_source)
assert_truthy(source_text:find("void Thing::A() {", 1, true), "expected the first selected declaration to be defined")
assert_truthy(source_text:find("void Thing::B(int x) {", 1, true), "expected the second one to be defined too")
assert_truthy(not source_text:find("Thing::C", 1, true), "expected a declaration outside the range to be left alone")

vim.fn.delete(root, "rf")

vim.cmd("qa!")
