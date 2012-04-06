#!/usr/bin/env ruby

require 'rubygems'
# CLI Tools
require 'commander/import'
require 'terminal-table'
# API Wrapper
require 'fogbugz'
# Utility functions
require 'active_support/inflector'
# Configuration
require 'configatron'
require './lib/config.rb'

# Define program parameters
program :name,           'FogBugz Command Line Client'
program :version,        '1.5.0'
program :description,    'Manage FogBugz cases from the command line. Ideal for batch processing.'
program :help_formatter, :compact
 
command :search do |c|
  # Definition
  c.syntax      = 'fogbugz search [query]'
  c.summary     = 'Search FogBugz for cases, using FogBugz query syntax.'
  c.description = 'Outputs a list of cases which match the provided query, or your current case list. Negations are performed using ! instead of -.'
  # Examples
  c.example       'Search for inactive cases by title', 'fogbugz search title:"Test Title" !status:active'
  c.example       'Search for a case by ID',            'fogbugz search ixbug:12'
  c.example       'Search for multiple cases by ID',    'fogbugz search 12,25,556'
  # Behavior
  c.action do |args, options|
    args = args || [] # Empty args defaults to returning current active case list
    query = args.join(' ').gsub('!', '-')
    # Search
    cases = search_all(query)
    show_cases cases
  end
end

command :list do |c|
  # Definition
  c.syntax      = 'fogbugz list [type]'
  c.summary     = 'Display a list of [projects, categories, people, statuses, areas, wikis, mailboxes]'
  c.description = 'Outputs the contents of the list in a easy to read format'
  # Options
  c.option        '--category ID', String, 'For statuses only, filter by a category.'
  c.option        '--resolved',            'For statuses only, only list resolved statuses.'
  c.option        '--all',                 'For people only, list all user records'
  c.option        '--include-active',      'For people only, include active users. With no options, this is the default behavior.'
  c.option        '--include-normal',      'For people only, include normal users. With no options, this is the default behavior.'
  c.option        '--include-deleted',     'For people only, include deleted users'
  c.option        '--include-community',   'For people only, include community users'
  c.option        '--include-virtual',     'For people only, include virtual users'
  # Examples
  c.example       'List all active users', 'fogbugz list people'
  # Behavior
  c.action do |args, options|
    # Defaults
    options.default :resolved => false
    options.default :category => ''

    headings = [] # Used for printing a table of results
    rows = [] # Used for printing a table of results
    list_options = {}

    unless args.empty?
      case args.join.to_sym
      when :statuses
        if options.resolved
          list_options['fResolved'] = 1
        end
        unless options.category.empty?
          list_options['ixCategory'] = options.category
        end
        statuses = list(:statuses, list_options)
        statuses.each do |status|
          rows << [ status['sStatus'], status['ixStatus'], status['ixCategory'] ]
        end
        print_table ['Status', 'StatusID', 'CategoryID'], rows
      when :people
        unless options.all
          if options.include_active
            list_options['fIncludeActive']  = 1
          end
          if options.include_normal
            list_options['fIncludeNormal']  = 1
          end
          if options.include_deleted
            list_options['fIncludeDeleted'] = 1
          end
          if options.include_community
            list_options['fIncludeCommunity'] = 1
          end
          if options.include_virtual
            list_options['fIncludeVirtual'] = 1
          end
        else
          list_options['fIncludeActive']    = 1
          list_options['fIncludeNormal']    = 1
          list_options['fIncludeDeleted']   = 1
          list_options['fIncludeCommunity'] = 1
          list_options['fIncludeVirtual']   = 1
        end
        people = list(:people, list_options)
        people.each do |person|
          email = person['sEmail'].length > 45 ? person['sEmail'][0..45] + '...' : person['sEmail']
          rows << [ person['sFullName'], email, person['fAdministrator'], person['fDeleted'], person['fVirtual'], person['dtLastActivity'] ]
        end
        print_table ['Name', 'Email', 'Admin?', 'Deleted?', 'Virtual?', 'Last Active'], rows
      when :projects
        projects = list(:projects)
        projects.each do |project|
          rows << [ project['ixProject'], project['sProject'], project['sPersonOwner'], project['sEmail'], project['sPhone'] ]
        end
        print_table ['ID', 'Project', 'Owner', 'Email', 'Phone'], rows
      when :categories
        categories = list(:categories)
        categories.each do |category|
          rows << [ category['ixCategory'], category['sPlural'] ]
        end
        print_table ['ID', 'Category'], rows
      when :areas
        areas = list(:areas)
        areas.each do |area|
          rows << [ area['ixArea'], area['sArea'], area['sProject'], ]
        end
        print_table ['ID', 'Area', 'Associated Project']
      when :wikis
        wikis = list(:wikis)
        wikis.each do |wiki|
          tagline = wiki['sTagLineHTML'] || 'N/A'
          tagline = tagline.length > 45 ? tagline[0..45] + '...' : tagline
          rows << [ wiki['ixWiki'], wiki['sWiki'], tagline ]
        end
        print_table ['ID', 'Wiki', 'Tag Line'], rows
      when :mailboxes
        mailboxes = list(:mailboxes)
        mailboxes.each do |mailbox|
          rows << [ mailbox['ixMailbox'], mailbox['sEmail'], mailbox['sEmailUser'] ]
        end
        print_table ['ID', 'Mailbox', 'User'], rows
      else
        print_message "This type of list is not supported yet.", :error
      end
    else
      print_message "You should specify a list type.", :warn
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
    args = args || []
    query = args.join(' ').gsub('!', '-')

    # Defaults
    options.default :close => false
    options.default :status => 45 # Fixed

    unless args.empty?
      # Get open cases assigned to me
      cases = search_open(query, nil, true)

      unless cases.empty?
        resolved = resolve cases, options.status
        print_message 'The following cases were resolved: ' + resolved.join, :success
        if options.close
          closed = close cases
          print_message 'The following cases were closed: ' + closed.join, :success
        end
      else
        print_message 'No open cases were found that match that query.', :warn
      end
    else
      print_message 'You must provide a search query.', :error
    end
  end
end

command :close do |c|
  # Definition
  c.syntax      = 'fogbugz close [query]'
  c.summary     = 'Close all cases that match a given query, and are assigned to you.'
  c.description = 'Searches for any cases that match a given criteria, and closes any cases that belong to you and have been resolved.'
  # Examples
  c.example       'Close by title',       'fogbugz close "Test Title"'
  c.example       'Close by ID',          'fogbugz close 12'
  c.example       'Close multiple by ID', 'fogbugz close 12, 25, 556'
  # Behavior
  c.action do |args, options|
    args = args || []
    query = args.join(' ').gsub('!', '-')

    unless args.empty?
      # Get open cases assigned to me that match the query
      cases = search_open(query, nil, true)

      unless cases.empty?
        closed = close cases
        print_message 'The following cases were closed: ' + closed.join, :success
      else
        print_message 'No open cases were found that match that query.', :warn
      end
    else
      print_message 'You must provide a search query.', :error
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
    args = args || []
    query = args.join(' ').gsub('!', '-')

    unless args.empty?
      cases = search_closed(query)
      unless cases.empty?
        reopened = reopen cases
        print_message 'The following cases were reopened: ' + reopened.join, :success
      else
        print_message 'No closed cases were found that match that query.', :warn
      end
    else
      print_message 'You must provide a search query.', :error
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
    @fogbugz_url = configatron.server.address || ask("What is the URL of your FogBugz server?")
    @auth_email  = configatron.user.email     || ask("What is your FogBugz email?")
    @auth_pass   = configatron.user.password  || ask("What is your FogBugz password?")

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
  #   columns: A comma separated list of columns to retrieve (optional)
  #   mine: A boolean flag indicating whether to return only cases that are assigned to you (optional, defaulting to false)
  ###############
  def search_all(query, columns = configatron.cases.default_columns, mine = false)
    client = authenticate
    # Ensure that columns is not nil
    if columns.nil?
      columns = configatron.cases.default_columns
    end

    results = nil
    if mine
      results = client.command(:search, :q => query + ' assignedto:me', :cols => columns)
    else
      results = client.command(:search, :q => query, :cols => columns)
    end

    unless results.nil?
      unless results['error'].nil?
        print_message results['error'], :error
        []
      else
        # Determine if this is a single result or many
        # and ensure that the result always an array
        cases = results['cases']['case'] || []
        if cases.is_a? Hash
          cases = [].push(cases)
        end

        cases
      end
    else
      []
    end
  end

  ###############
  # Search Open
  # -------------
  # Execute a simple find. Returns only cases that are active.
  # Params:
  #   query: A string to search for (can be a case, csv of cases, general string)
  #   columns: A comma separated list of columns to retrieve (optional)
  #   mine: A boolean flag indicating whether to return only cases that are assigned to you (optional, defaulting to false)
  ###############
  def search_open(query, columns = configatron.cases.default_columns, mine = false)
    cases = search_all(query + ' status:"active"', columns, mine)
    cases
  end

  ###############
  # Search Closed
  # -------------
  # Execute a simple find. Returns only cases that are closed.
  # Params:
  #   query: A string to search for (can be a case, csv of cases, general string)
  #   columns: A comma separated list of columns to retrieve (optional)
  #   mine: A boolean flag indicating whether to return only cases that are assigned to you (optional, defaulting to false)
  ###############
  def search_closed(query, columns = configatron.cases.default_columns, mine = false)
    cases = search_all(query + ' -status:"active"', columns, mine)
    cases
  end

  ###############
  # Get List
  # -------------
  # Fetches a list of objects from FogBugz
  # Params:
  #   type: The type of object to list
  #   options: Options specific to the list being fetched. These are FogBugz query options, see the XML API for info.
  ###############
  def list(type, options = {})
    command = "list#{type.capitalize}".to_sym
    client = authenticate
    results = client.command(command, options)
    results = results[type.to_s][type.to_s.singularize] || []
  end

  ###############
  # Resolve Cases
  # -------------
  # Takes an array of cases, and resolves them.
  # Params:
  #   cases: An array of cases
  # Returns:
  #   An array of bug IDs resolved
  ###############
  def resolve(cases, status = 45)
    client = authenticate

    resolved = []
    if configatron.output.progress
      progress cases do |c|
        client.command(:resolve, :ixBug => c['ixBug'], :ixStatus => status)
        resolved.push(c['ixBug'])
      end
    else
      cases.each do |c|
        client.command(:close, :ixBug => c['ixBug'], :ixStatus => status)
        resolved.push(c['ixBug'])
      end
    end

    resolved
  end

  ###############
  # Close Cases
  # -------------
  # Takes an array of cases, and closes them.
  # Params:
  #   cases: An array of cases
  # Returns:
  #   An array of bug IDs closed
  ###############
  def close(cases)
    client = authenticate

    closed = []
    if configatron.output.progress
      progress cases do |c|
        client.command(:close, :ixBug => c['ixBug'])
        closed.push(c['ixBug'])
      end
    else
      cases.each do |c|
        client.command(:close, :ixBug => c['ixBug'])
        closed.push(c['ixBug'])
      end
    end

    closed
  end

  ###############
  # Reopen Cases
  # -------------
  # Takes an array of cases, and reopens them.
  # Params:
  #   cases: An array of cases
  # Returns:
  #   An array of bug IDs reopened
  ###############
  def reopen(cases)
    client = authenticate

    reopened = []
    if configatron.output.progress
      progress cases do |c|
        client.command(:reopen, :ixBug => c['ixBug'])
        reopened.push(c['ixBug'])
      end
    else
      cases.each do |c|
        client.command(:reopen, :ixBug => c['ixBug'])
        reopened.push(c['ixBug'])
      end
    end

    reopened
  end

  ###############
  # Show Cases
  # -------------
  # Takes an array of cases, and either prints them to a table, or if the array is empty, prints that information
  # Params:
  #   cases: An array of cases
  ###############
  def show_cases(cases)
    p
    unless cases.empty?
      headings = ['BugID', 'Status', 'Title', 'Assigned To']
      rows = []
      if configatron.output.colorize
        cases.each do |c|
          status = c['sStatus']
          if status == 'Active'
            status = colorize(status, configatron.colors.green)
          end
          rows << [ c['ixBug'], status, c['sTitle'], c['sPersonAssignedTo'] ]
        end
      else
        cases.each do |c|
          rows << [ c['ixBug'], c['sStatus'], c['sTitle'], c['sPersonAssignedTo'] ]
        end
      end
      print_table headings, rows
    else
      print_message 'No open cases were found that match your query.', :warn
    end
  end

  ###############
  # Print Table
  # -------------
  # Takes an array of headings and an array of rows, and prints a table
  ###############
  def print_table(headings, rows)
    unless configatron.output.clean
      table = Terminal::Table.new :headings => headings, :rows => rows
      puts table
    else
      rows.each {|row| puts '"' + row.join('","') + '"' }
    end
  end

  ###############
  # Print Message
  # -------------
  # Prints a message to the terminal, colored according to it's type
  # Params:
  #   text: The message to print
  #   type: Choose one => [:error, :warn, :success, :info]
  ###############
  def print_message(text, type)
    puts
    if configatron.output.colorize
      case type
      when :error
        puts colorize(text, configatron.colors.red)
      when :warn
        puts colorize(text, configatron.colors.yellow)
      when :success
        puts colorize(text, configatron.colors.green)
      when :info
        puts text
      end
    else
      puts text
    end
  end

  ###############
  # Colorize
  # -------------
  # Takes a string of text and adds ANSI color code sequences for colorized output in a terminal
  ###############
  def colorize(text, color_code)
    reset = "e[0m" # Resets color to default for all text after the colorized text
    "#{color_code}#{text}#{reset}"
  end