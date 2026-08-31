.pragma library

var HANDLE = "gshulga_dashboard_blur_rule"
var VERSION_HANDLE = "gshulga_dashboard_blur_rule_version"
var RULE_VERSION = 2
var RULE_NAME = "gshulga-dashboard-blur"
var NAMESPACE = "gshulga-dashboard"

function ruleExpression(enabled) {
  var state = enabled === true ? "true" : "false"
  return "if " + HANDLE + " ~= nil and " + VERSION_HANDLE + " ~= " + RULE_VERSION + " then\n"
    + "  " + HANDLE + ":set_enabled(false)\n"
    + "end\n"
    + "if " + HANDLE + " == nil or " + VERSION_HANDLE + " ~= " + RULE_VERSION + " then\n"
    + "  " + HANDLE + " = hl.layer_rule({\n"
    + "    name = \"" + RULE_NAME + "\",\n"
    + "    match = { namespace = \"" + NAMESPACE + "\" },\n"
    + "    blur = true,\n"
    + "    xray = true,\n"
    + "  })\n"
    + "  " + VERSION_HANDLE + " = " + RULE_VERSION + "\n"
    + "end\n"
    + HANDLE + ":set_enabled(" + state + ")"
}
