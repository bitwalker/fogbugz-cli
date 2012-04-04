#!/usr/bin/env ruby

require 'rubygems'
require 'commander/import'
require 'fogbugz'
require 'active_support/inflector'
require 'rconfig'

# Import configuration
RConfig.config_paths = ['#{APP_ROOT}/config']

# Define program parameters
program :name,           'FogBugz Command Line Client'
program :version,        '1.0.0'
program :description,    'Manage FogBugz cases from the command line. Ideal for batch processing.'
program :help_formatter, :compact
 
command :search do |c|
  # Definition
  c.syntax      = 'fogbugz search [query]'
  c.summary     = 'Search FogBugz for cases.'
  c.description = 'Outputs a list of cases which match the provided query, or your current case list.'
  # Options
  c.option        '--open', 'Only return open cases'
  # Examples
  c.example       'Search for a case by title',      'fogbugz search "Test Title"'
  c.example       'Search for a case by ID',         'fogbugz search 12'
  c.example       'Search for multiple cases by ID', 'fogbugz search 12,25,556'
  # Behavior
  c.action do |args, options|
    client = authenticate
    args = args || []
    # Specify columns
    cols  = "ixBug,ixBugParent,ixBugChildren,fOpen,sTitle,sPersonAssignedTo,sEmailAssignedTo,sStatus"
    cases = search(args.join, cols)
    if options.open then cases.reject! {|c| c['fOpen'] == 'false'} end
    unless cases.empty?
      puts # Empty string for formatting
      cases.each do |c|
        p "#{c['ixBug']} - #{c['sStatus']} - #{c['sTitle']} - Assigned To: #{c['sPersonAssignedTo']}"
      end
    else
      p 'No open cases were found that match your query.'
    end
  end
end

command :list do |c|
  # Definition
  c.syntax      = 'fogbugz list [type]'
  c.summary     = 'Display a list of [projects, categories, people, statuses]'
  c.description = 'Outputs the contents of the list in a easy to read format'
  # Options
  c.option        '--category ID', String, 'For statuses only, filter by a category.'
  c.option        '--resolved', 'For statuses only, only list resolved statuses.'
  # Examples
  c.example       'List all active users', 'fogbugz list people'
  # Behavior
  c.action do |args, options|
    # Defaults
    options.default :resolved => false
    options.default :category => ''

    client = authenticate
    unless args.empty?
      puts
      case args.join
      when "statuses"
        opts = {}
        if options.resolved
          opts['fResolved'] = 1
        end
        unless options.category.empty?
          opts['ixCategory'] = options.category
        end
        statuses = list("statuses", opts)
        statuses.each do |status|
          p "#{status['sStatus']} - #{status['ixStatus']} - Category: #{status['ixCategory']}"
        end
      else
        p "This type of list is not supported yet."
      end
    else
      puts
      p "You should specify a list type."
    end
  end
end

command :resolve do |c|
  # Definition
  c.syntax      = 'fogbugz resolve [query]'
  c.summary     = 'Resolve all cases that match a given query, and are assigned to you.'
  c.description = 'Searches for any cases that match a given criteria, and resolves any matches that belong to you.'
  # Options
  c.option        '--close', 'In addition to resolving the case, close it out.'
  c.option        '--status ID', String, 'The status with which to resolve this case. Default is 45 (Fixed).'
  # Examples
  c.example       'Resolve by title',       'fogbugz resolve "Test Title"'
  c.example       'Resolve by ID',          'fogbugz resolve 12'
  c.example       'Resolve multiple by ID', 'fogbugz resolve 12, 25, 556'
  # Behavior
  c.action do |args, options|
    # Defaults
    options.default :close => false
    options.default :status => 45 # Fixed

    client = authenticate
    if (!args.nil? and !args.empty?)
      # Request results
      cases = search(args.join, "ixBug,fOpen,sEmailAssignedTo")
      cases = cases.reject {|c| c['fOpen'] == 'false' and c['sEmailAssignedTo'] != @auth_email}
      unless cases.empty?
        resolved = []
        progress cases do |c|
          client.command(:resolve, :ixBug => c['ixBug'], :ixStatus => options.status)
          if options.close
            client.command(:close, :ixBug => c['ixBug'])
          end
          resolved.push(c['ixBug'])
        end
        p 'The following cases were resolved: ' + resolved.join
      else
        p 'No open cases were found that match that query.'
      end
    else
      p 'You must provide a search query.'
    end
  end
end

command :close do |c|
  # Definition
  c.syntax      = 'fogbugz close [query]'
  c.summary     = 'Close all cases that match a given query, and are assigned to you.'
  c.description = 'Searches for any cases that match a given criteria, and resolves any matches that belong to you.'
  # Examples
  c.example       'Close by title',       'fogbugz close "Test Title"'
  c.example       'Close by ID',          'fogbugz close 12'
  c.example       'Close multiple by ID', 'fogbugz close 12, 25, 556'
  # Behavior
  c.action do |args, options|
    client = authenticate
    if (!args.nil? and !args.empty?)
      # Request results
      cases = search(args.join, "ixBug,fOpen,sEmailAssignedTo")
      cases = cases.reject {|c| c['fOpen'] == 'false' and c['sEmailAssignedTo'] != @auth_email}
      unless cases.empty?
        closed = []
        progress cases do |c|
          client.command(:close, :ixBug => c['ixBug'])
          closed.push(c['ixBug'])
        end
        p 'The following cases were closed: ' + closed.join
      else
        p 'No open cases were found that match that query.'
      end
    else
      p 'You must provide a search query.'
    end
  end
end

command :reopen do |c|
  # Definition
  c.syntax      = 'fogbugz reopen [query]'
  c.summary     = 'Reopen all cases that match a given query, and are assigned to you.'
  c.description = 'Searches for any cases that match a given criteria and reopens them.'
  # Examples
  c.example       'Resolve by title',       'fogbugz reopen "Test Title"'
  c.example       'Resolve by ID',          'fogbugz reopen 12'
  c.example       'Resolve multiple by ID', 'fogbugz reopen 12, 25, 556'
  # Behavior
  c.action do |args, options|
    client = authenticate
    if (!args.nil? and !args.empty?)
      cases = search(args.join, "ixBug,fOpen")
      cases = cases.reject { |c| c['fOpen'] == 'true' }
      unless cases.empty?
        reopened = []
        progress cases do |c|
          client.command(:reopen, :ixBug => c['ixBug'])
          reopened.push(c['ixBug'])
        end
        p 'The following cases were reopened: ' + reopened.join
      else
        p 'No closed cases were found that match that query.'
      end
    else
      p 'You must provide a search query.'
    end
  end
end

private

  ###############
  # Authenticate
  # -------------
  # Authenticate fogbugz client to server. Cache auth token for reuse.
  ###############
  def authenticate
    @fogbugz_url = RConfig.fogbugz.server.address || ask("What is the URL of your FogBugz server?")
    @auth_email  = RConfig.fogbugz.user.email     || ask("What is your FogBugz email?")
    @auth_pass   = RConfig.fogbugz.user.password  || ask("What is your FogBugz password?")

    # Cache the authentication token
    if @token.nil?
      client = Fogbugz::Interface.new(:email => @auth_email, :password => @auth_pass, :uri => @fogbugz_url)
      client.authenticate
      @token = client.token
      client
    else
      client = Fogbugz::Interface.new(:token => @token, :uri => @fogbugz_url)
    end
  end

  ###############
  # Search
  # -------------
  # Execute a simple find. If query is malformed, it will return all cases that belong to the caller.
  # Params:
  #   query: A string to search for (can be a case, csv of cases, general string)
  #   columns: A comma separated list of columns to retrieve, defaults to the bug ID
  ###############
  def search(query, columns)
    client = authenticate
    results = client.command(:search, :q => query, :cols => columns || "ixBug")

    unless results.nil?
      # Determine if this is a single result or many
      # and ensure that the result always an array
      cases = results['cases']['case'] || []
      if cases.is_a? Hash
        cases = [].push(cases)
        cases
      else
        cases
      end
    else
      []
    end
  end

  def list(type, options = {})
    command = "list#{type.capitalize}".to_sym
    client = authenticate
    results = client.command(command, options)
    results = results[type][type.singularize] || []
  end