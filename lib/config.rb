require 'configatron'

# Server
configatron.server.address = 'http://fogbugz' # Can be any URL, use HTTPS when possible

# User
configatron.user.email    = 'test@test.com'
configatron.user.password = 'testpass'

# Output
configatron.output.progress = true
configatron.output.colorize = true # Colorize output
configatron.output.clean    = false # Clean output for piping/export (renders as comma-separated, "-quoted values)

# Colors
#  Bright
configatron.colors.green   = "1;32"
configatron.colors.yellow  = "1;33"
configatron.colors.red     = "1;31"
configatron.colors.blue    = "1;34"
configatron.colors.magenta = "1;35"
configatron.colors.cyan    = "1;36"
configatron.colors.white   = "1;37"
configatron.colors.black   = "1;30"

# Cases
cols =        "ixBug,ixBugParent,ixBugChildren,sStatus,sTitle,sLatestTextSummary,sProject,sPersonAssignedTo,"
cols = cols + "sEmailAssignedTo,hrsOrigEst,hrsCurrEst,hrsElapsed,sCustomerEmail,sTicket,tags,sCategory,fSubscribed"
configatron.cases.default_columns = cols