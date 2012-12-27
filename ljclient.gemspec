Gem::Specification.new do |s|
  s.name = 'ljclient'
  s.version = '1.0.0'
  s.date = '2012-11-07'
  s.summary = 'LiveJournal client library'
  s.description = 'A library for posting to LiveJournal'
  s.authors = ['Watts Martin']
  s.email = 'layotl@gmail.com'
  s.files = ['lib/ljclient.rb']
  s.add_dependency 'rdiscount'
  s.executables << 'ljpost'
  s.homepage = 'http://github.com/chipotle/ljpost'
end
