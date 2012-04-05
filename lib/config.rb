require 'configatron'

# Server
configatron.server.address = 'http://fogbugz' # Can be any URL, use HTTPS when possible

# User
configatron.user.email    = 'paul.schoenfelder@protolabs.com' #'test@test.com'
configatron.user.password = 'pq92!cb' #'testpass'

# Output
configatron.output.progress = true
configatron.output.colorize = true

# Cases
configatron.cases.default_columns = "ixBug,ixBugParent,ixBugChildren,fOpen,sTitle,sPersonAssignedTo,sEmailAssignedTo,sStatus"