#!/bin/ruby

def parse(filename)
  r = {}
  File.open(filename).each do |l|
    name, city, phone = l.strip.split(',')
    i = {}
    i[:city] = city if city != nil
    i[:phone] = phone if phone != nil
    r[name] = i
  end
  r
end

o = parse('old.csv')
n = parse('new.csv')

o.merge!(n) { |k, ov, nv| ov.merge(nv) }

o.each { |k,v| puts "#{k},#{v[:city]},#{v[:phone]}"}
