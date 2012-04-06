require 'configatron'

# Server
configatron.server.address = 'http://fogbugz' # Can be any URL, use HTTPS when possible

# User
configatron.user.email    = 'test@test.com'
configatron.user.password = 'testpass'

# Output
configatron.output.progress = true
configatron.output.colorize = false
configatron.output.clean    = false # Clean output for piping/export (renders as comma-separated, "-quoted values)

# Colors
configatron.colors.green   = "e[32m"
configatron.colors.yellow  = "e[33m"
configatron.colors.red     = "e[31m"
configatron.colors.blue    = "e[34m"
configatron.colors.magenta = "e[35m"
configatron.colors.cyan    = "e[36m"
configatron.colors.white   = "e[37m"
configatron.colors.black   = "e[30m"

# Cases
configatron.cases.default_columns = "ixBug,ixBugParent,ixBugChildren,fOpen,sTitle,sPersonAssignedTo,sEmailAssignedTo,sStatus"