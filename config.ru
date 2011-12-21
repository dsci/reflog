# config.ru
require File.expand_path(File.join(File.dirname(__FILE__), 'grit_demo'))
run GritDemo::Application