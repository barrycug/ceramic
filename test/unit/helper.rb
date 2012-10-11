require "test/unit"

libdir = File.dirname(__FILE__) + "/../lib"
$LOAD_PATH.unshift libdir unless $LOAD_PATH.include?(libdir)

require "cover"
