Gem::Specification.new do |s|
  s.name = 'ljclient'
  s.version = '0.9.9'
  s.date = '2012-04-24'
  s.summary = 'LiveJournal client library'
  s.description = 'A library for posting to LiveJournal'
  s.authors = ['Watts Martin']
  s.email = 'layotl@gmail.com'
  s.files = ['lib/ljclient.rb']
  s.add_dependency 'rdiscount'
  s.executables << 'ljpost'
end
