# LJClient & LJPost

LJClient is a straightforward LiveJournal client library written in Ruby.

LJPost is an "interface-free" LiveJournal client that can be called as a
filter from a text editor. It supports all of LiveJournal's features and can
integrate with RDiscount for Markdown support. It relies on LJClient.

## Installation

Best installed as a gem:

    gem install ljclient-0.9.7.gem

This should install both the library and the command-line client.

## Usage

### LJPost

Create a config file named `~/.ljpostrc`, a YAML file consisting of three
required directives and one optional directive:

    host: www.livejournal.com (or compatible site)
    username: your_username
    password: your_password
    markdown: on|off

If `markdown` is enabled, your posts will be processed through Markdown
(although this can disabled on a per-post basis).

Run `ljpost` from the command line. If you give a filename as an argument,
that filename will be used for input; otherwise, ljpost reads from `stdin`.

Normally, a succesful run will print nothing to your terminal. Any errors will
cause an error message to be printed to `stderr` and the program will exit
with a status of 1. LiveJournal's server has the ability to send a message
back on a successful post; if such a message is received, it will be printed
to `stdout` on exit.

Entries are formatted like mail messages, with a YAML-style header block. The
header block can be separated from the text body by one blank line, _or_
bracketed by "---" lines, similar to (and deliberately compatible with!)
Octopress/Jekyll input files. A typical post might look like:

    ---
    subject: Ruby-LJPost
    mood: geeky
    ---
    I'd like to tell you all about this nifty command-line client for
    LiveJournal written in Ruby.

The following headers are recognized. All headers are optional, although
including a subject/title is strongly recommended. When a header is not
present, the selection will use the default set in your LJ user information.
**Headers must be in lowercase.**

    subject: the subject of your post
    title: an alternate way to specify the subject
    mood: your mood (free-form text)
    music: music you're listening to
    picture: a picture keyword on the LiveJournal server
    comments: yes or no; allow or disallow on this entry
    email: yes or no; email comments on this post to you
    preformatted: yes or no; if yes, assume entry is in HTML
    journal: name of a journal to post to
    screening: all | anonymous | non-friends | none
      Choose screening level for comments on this entry
    security: public | private | friends | groupname(s)
      Choose security level for this entry.
    date: date and time for this entry
    backdate: yes or no

You must install the `rdiscount` gem for Markdown support.

## LJClient Library

No documentation yet (boo), but the file has RDoc-style comments.

## History

Originally written in 2005; updated in 2009 and 2012

## Author

Watts Martin
