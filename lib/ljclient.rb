#!/usr/bin/env ruby

# Implements the LiveJournal module. Primary documentation is for
# the LiveJournal::Client class.
#
# Copyright (c) 2005-2012 Watts Martin <layotl@gmail.com>

require 'xmlrpc/client'
require 'digest/md5'

# Return boolean true or false depending on a string value.
#
# :call-seq:
#    bool(string) -> true, false, nil
#
# If the string is *y*, *yes* or *on*, _true_ will be returned.  If
# the string is *n*, *no* or *off*, _false_ will be returned.  For any
# other value, _nil_ will be returned.

def bool(val)
  case val.to_s.downcase
  when 'y', 'yes', 'on', 't', 'true'
    true
  when 'n', 'no', 'off', 'f', 'false'
   false
  else
    nil
  end
end

# *LiveJournal* is a module for communicating with LiveJournal-compatible
# weblog servers. It requires XMLRPC and Digest (standard Ruby libraries).

module LiveJournal
  # ID string to send to LiveJournal server
  CLIENT = 'Ruby-LjClient/0.97'

  # error codes
  LJERR_NO_LOGIN = 101
  LJERR_CFINTERVAL = 102
  LJERR_INVALID_JOURNAL = 103
  LJERR_BAD_SCREEN = 104
  LJERR_BAD_FGROUP = 105

  # Exception class. Errors are returned as a number and string pair
  # in the errVal and errString attributes respectively.
  # LiveJournal::Client objects override the exception
  # handling in XMLRPC::Client and return its faultString and faultCode
  # values in errString and errVal.

  class LjException < Exception
    attr_reader :errVal, :errString

    def initialize(errVal, errString)
      @errVal = errVal
      @errString = errString
    end
  end

  # The client class for communicating with LiveJournal-compatible
  # servers. This class extends XMLRPC::Client with LJ-specific
  # methods and state variables; native XMLRPC methods such as *call*
  # and *cookie* are available.

  class Client < XMLRPC::Client
    # username (must be set before login)
    attr :username, true
    # true if fast servers can be used
    attr :fastserver
    # array of journal names user can post to
    attr :usejournals
    # true if user is logged in
    attr :logged_in
    # hash of friend groups user has created, with four keys per group:
    # name, public, id, and sortorder
    attr :friendgroups
    # message returned from server after last command, if any
    attr :message
    # load mood_list with an array of hashes you've saved for the mood
    # list and the Client#login method will update it if necessary;
    # set it to *true* to download the array initially. (Don't set the
    # attribute at all if you don't want to use mood lists.)
    attr :mood_list, true

    protected :password

    # :call-seq:
    #   Client#new(host) -> object
    #
    # Note that the *host* argument is _not_ a URL, but a fully-qualified
    # domain name (i.e., "www.livejournal.com").

    def initialize(host)
      super(host,'/interface/xmlrpc')
      @logged_in = false
      @fastserver = false
      @lastupdate = ''
    end

    # Log into server.
    #
    # :call-seq:
    #   Client#login(username,password)   -> boolean
    #
    # The login function will return _true_ if a message has been sent
    # back from the LiveJournal server. If so, that message can be
    # accessed with the <b>Client#message</b> attribute.
    #
    # If you want to download a list of moods, load the mood list array
    # *mood_list* first, or set *mood_list* to *true* to download for
    # the first time. (The *mood_list* is an array of hashes, with the
    # hash keys 'id', 'name' and 'parent'.) After downloading, this value
    # should be cached by your client.

    def login(username, password)
      @username = username
      @password = password
      challenge, response = getchallenge
      login_vars = {
        'username' => @username,
        'clientversion' => CLIENT,
        'auth_method' => 'challenge',
        'auth_challenge' => challenge,
        'auth_response' => response
      }
      if @mood_list == true
        login_vars['getmoods'] = 0
      elsif @mood_list.kind_of? Array
        i = @mood_list.max { |a,b| a['id'] <=> b['id'] }
        login_vars['getmoods'] = i['id']
      end
      login = self.call('LJ.XMLRPC.login', login_vars)
      @fastserver = login['fastserver'] == 1
      @usejournals = login['usejournals']
      @logged_in = true
      @next_check_ok = 0
      @friendgroups = login['friendgroups']
      if @mood_list
        if @mood_list == true
          @mood_list = login['moods']
        else
          @mood_list << login['moods']
        end
      end
      if login.has_key?('message')
        @message = login['message']
        return true
      else
        return false
      end
    rescue XMLRPC::FaultException => e
      raise LjException.new(e.faultCode, e.faultString)
    end

    # Send a new post. You must have successfully logged in to use this
    # method.
    #
    # :call-seq:
    #   Client#postevent(event, {:attr => value, ...}) -> itemid
    #
    # The "event" is the text of the post. All other arguments are
    # optional, and specified by symbol:
    #
    # [:subject]      subject of the post
    # [:journal]      the name of the journal to post to
    # [:security]     the security level, which must be 'public', 'private',
    #                 'friends', or the name of a valid friends group for
    #                 the user
    # [:date]         time of the post (Ruby datetime object; defaults to 'now')
    # [:preformatted] text is already formatted as HTML (yes/no)
    # [:comments]     allow comments (yes/no)
    # [:email]        email comments (yes/no)
    # [:screening]    screen comments from 'all', 'none', 'anonymous'
    #                 or 'non-friends'
    # [:metadata] hash of other fields to include
    #
    # The metadata hash is where fields like 'current_mood',
    # 'current_music', and 'picture_keyword' can be sent to the server.
    # There is no checking done on the metadata hash for validity,
    # so the keys and values must be accepted by the server.
    #
    # Example:
    #
    #   subject = "Ruby LiveJournal Tools"
    #   event_text = "Eventually, I'll think of a use for these!"
    #   metadata = {
    #     'current_mood' => 'sleepy',
    #     'current_music' => '1812 Overture'
    #   }
    #
    #   s = LiveJournal::Client.new('www.livejournal.com')
    #   s.login('chipotle', 'password')
    #   s.postevent(event_text, :subject => subject, :metadata => metadata)
    #
    # Note that the postevent method's symbol arguments overlap with
    # some fields that are sent to LJ servers as metadata. For instance,
    # the <b>:comments</b> argument is translated to the <b>opt_nocomments</b>
    # metadata field, and <b>:security</b> sets the proper values for the
    # <b>security</b> and <b>allowmask</b> metadata fields. If you prefer, you
    # can use the LiveJournal metadata directly with the <b>:metadata</b>
    # argument, but if you do that, you must not use the symbolic arguments.
    #
    # This method returns an integer representing the itemid of the created
    # post.

    def postevent(event, args)
      raise LjException.new(LJERR_NO_LOGIN,'not logged in') if not @logged_in
      post = parse_post(event,args)
      self.cookie = "ljfastserver=1" if @fastserver
      r = self.call("LJ.XMLRPC.postevent",post)
      return r['itemid']
    rescue XMLRPC::FaultException => e
      raise LjException.new(e.faultCode,e.faultString)
    end

    # Edit an existing post. You must have successfully logged in to use
    # this method.
    #
    # :call-seq:
    #   Client#editevent(event, :itemid => id, {:attr => value, ...}) -> itemid
    #
    # All parameters are the same as the Client#postevent method, with
    # the exception of the required *:itemid* attribute.
    #
    # This method returns an integer value of the event's itemid.

    def editevent(event, args)
      raise LjException.new(LJERR_NO_LOGIN,'not logged in') if not @logged_in
      post = parse_post(event, args)
      self.cookie = "ljfastserver=1" if @fastserver
      r = self.call("LJ.XMLRPC.editevent",post)
      return r['itemid']
    rescue XMLRPC::FaultException => e
      raise LjException.new(e.faultCode, e.faultString)
    end

    # Check to see if your friends list has been updated.
    #
    # :call-seq:
    #   Client#checkfriends -> {new,interval,count,total}
    #   Client#checkfriends(groups)
    #
    # The optional argument is a list of friends groups to check, as
    # one string with group names separated by spaces (i.e., "work
    # home"). This function will # return *true* if there are new
    # entries or *false* if there # are not.
    #
    # The server will specify a limit on how often this method may be
    # called, and an LjException will be raised if you poll more often.
    # The next allowable time to poll is available in the *next_check_ok*
    # attribute, specified in Unix time (elapsed seconds sice 1/1/1970).

    def checkfriends(groups=nil)
      raise LjException.new(LJERROR_NO_LOGIN,'not logged in') if not @logged_in
      if Time.now.to_i < @next_check_ok
        raise LjException.new(LJERR_CFINTERVAL,
        'checkfriends interval has not elapsed')
      end
      data = {
        'username' => @username,
        'auth_method' => 'challenge',
        'lastupdate' => @lastupdate
      }
      data['mask'] = get_mask(groups) unless groups.nil?
      data['auth_challenge'], data['auth_response'] = getchallenge
      r = self.call("LJ.XMLRPC.checkfriends", data)
      @lastupdate = r['lastupdate']
      @next_check_ok = Time.now.to_i + r['interval']
      if r['new'] == 1
        true
      else
        false
      end
    rescue XMLRPC::FaultException => e
      raise LjException.new(e.faultCode, e.faultString)
    end

    # the remaining methods are private to the class
    private

    # get challenge for authentication
    def getchallenge
      result = self.call('LJ.XMLRPC.getchallenge')
      challenge = result['challenge']
      digest = Digest::MD5.new
      digest << challenge
      digest << Digest::MD5.hexdigest(@password)
      [challenge, digest.hexdigest]
    rescue XMLRPC::FaultException => e
      raise LjException.new(e.faultCode, e.faultString)
    end

    # parse arguments for editevent and postevent
    def parse_post(event, args)
      props = Hash.new
      if args[:metadata] then
        props = args[:metadata]
      end
      if args[:date] then
        t = args[:date]
      else
        t = Time.now
      end
      post = {
        'username' => @username,
        'auth_method' => 'challenge',
        'lineendings' => 'unix',
        'event' => event,
        'subject' => args[:subject],
        'year' => t.year,
        'mon' => t.month,
        'day' => t.day,
        'hour' => t.hour,
        'min' => t.min
      }
      if args[:journal]
        journal = args[:journal]
        if @usejournals.include?(journal)
          post['usejournal'] = journal
        else
          raise LjException.new(LJERR_INVALID_JOURNAL,
          "Invalid journal name '#{journal}'")
        end
      end
      props['opt_preformatted'] = bool(args[:preformatted]) if args[:preformatted]
      props['opt_nocomments'] = !bool(args[:comments]) if args[:comments]
      props['opt_noemail'] = !bool(args[:email]) if args[:email]
      security = args[:security]
      if security
        level = security.downcase
        post['security'] = case level
        when 'public' then level
        when 'private' then level
        when 'friends'
          post['allowmask'] = 1
          'usemask'
        else
          post['allowmask'] = get_mask level
          'usemask'
        end
      end
      screening = args[:screening]
      if screening
        props['opt_screening'] =
        case screening.downcase
        when 'all', 'a' then 'A'
        when 'none', 'n' then 'N'
        when 'anonymous', 'r' then'R'
        when 'non-friends', 'f' then 'F'
        else
          raise LjException.new(LJERR_BAD_SCREEN,
          "Screening must be 'all', 'none', 'anonymous' or 'non-friends'")
        end
      end
      props.delete_if { |k,v| v.nil? }
      post['itemid'] = args[:itemid] if args[:itemid]
      post['props'] = props unless props.empty?
      post['auth_challenge'], post['auth_response'] = getchallenge
      # puts post.inspect
      return post
    end

    # convert list of friend groups to proper mask
    def get_mask(groups)
      mask = 0
      groups.split.each do |i|
        selected = @friendgroups.find { |g| g['name'] == i}
        if selected.nil?
          raise LjException.new(LJERR_BAD_FGROUP,"Invalid friends group '#{i}'")
        else
          mask += 2 ** selected['id']
        end
      end
      return mask
    end

  end # of class definition

end # of module definition
