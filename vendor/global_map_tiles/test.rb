zoom = 12
lat = 38
lon = -122.1
lat2 = 38.1
lon2 = -122

py = `python globalmaptiles.py #{zoom} #{lat} #{lon} #{lat2} #{lon2}`
rb = `ruby global_map_tiles.rb #{zoom} #{lat} #{lon} #{lat2} #{lon2}`

result = py == rb

puts result ? "They match." : "They don't match."

unless result
  puts "python:"
  puts py
  puts "ruby:"
  puts rb
end

python_lines = py.lines
ruby_lines = rb.lines

python_lines.each do |pl|
  rl = ruby_lines.next
  if pl == rl
    puts "same: " + pl
  else
    puts "py:   " + pl
    puts "rb:   " + rl
  end
end
