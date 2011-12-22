# config.ru
require File.expand_path(File.join(File.dirname(__FILE__), 'reflog'))
run Reflog::Application