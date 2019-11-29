#!/bin/ruby

require 'set'

# This script loads file beds-original.csv with all available beds
# and file extra-beds-2-3.csv with rooms of buildings 2 and 3 where
# extra bed can be placed. The result is output to stdout with
# all available beds in format appropriate for our google sheets
# engine :) Some diagnostics is written to stderr too.

Info = {
'1 местный стандартный' => { beds: 1, cat: :standard },
'"1 местный стандарт ""Улучшенный"""' => { beds: 1, cat: :comfort },
'1 местный эконом' => { beds: 1, cat: :econom },
'2 местный стандартный' => { beds: 2, cat: :standard },
'"2 местный стандарт Улучшенный""с двухспальной кроватью"' => { beds: 2, cat: :comfort1b },
'2 местный эконом' => { beds: 2, cat: :econom },
'"2 м стандарт ""Улучшенный"""' => { beds: 2, cat: :comfort },
'3 местный стандартный' => { beds: 3, cat: :standard },
'3 местный эконом' => { beds: 3, cat: :econom },
'Люкс 2комнатный' => { beds: 2, cat: :lux },
'Полулюкс' => { beds: 2, cat: :poorlux },
'Полулюкс двухкомнатный' => { beds: 2, cat: :poorlux2k },
'Стандарт Family' => { beds: 2, cat: :family },
}

cats = {
  econom: 'Эконом',
  standard: 'Стандарт',
  comfort: 'Комфорт',
  comfort1b: 'Ком1кровать',
  lux: 'Люкс 2к',
  poorlux: 'Полулюкс',
  poorlux2k: 'Полулюкс 2к',
  family: 'Фемели',
}

bednames = {
  1 => 'Одноместный',
  2 => 'Двухместный',
  3 => 'Трехместный',
}


beds = []

idx = nil
File.open('beds-original.csv').each do |l|
  if idx.nil?
    head = l.strip.split(',')
    idx = {
      build: head.index('Корпус'),
      room: head.index('Комната'),
      category: head.index('Категория'),
    }
    next
  end
  d = l.strip.split(',')
  a = {
    build: d[idx[:build]],
    room: d[idx[:room]],
  }
  cat2 = Info[d[idx[:category]]]
  beds.push(a.merge(cat2))

end

head = nil
extra = { '2' => Set.new, '3' => Set.new }
File.open('extra-beds-2-3.csv').each do |l|
  d = l.strip.split(',')
  if head.nil?
    head = d
    next
  end
  d = l.strip.split(',')
  s = extra[d[0]]
  raise "Unexpected building in extra: #{d[0]}" if s.nil?
  raise "Duplicate room in extra: #{d[1]}" if s.include?(d[1])
  s.add(d[1])
end

all_beds = []
beds.size.times do |i|
  b = beds[i].clone
  b[:dop] = false
  all_beds.push(b)
  next if i + 1 < beds.size and beds[i + 1] == beds[i]

  dops = 0

  # standart rooms with extra place are described in extra file
  e = extra[b[:build]]
  if e and e.include?(b[:room])
    if b[:cat] == :comfort
      STDERR.puts "Comfort room in extra list, build: #{b[:build]}, room: #{b[:room]}"
    end
    e.delete(b[:room])
    dops = 1
  end

  if [:comfort, :comfort1b, :poorlux, :lux].include?(b[:cat]) or
     (b[:cat] == :econom and b[:beds] == 1) or
     (b[:cat] == :econom and b[:beds] > 1 and ['5', '9', '10'].include?(b[:room]))

    dops = 1
  elsif b[:cat] == :family

    if b[:build] == '5'
      if ['2Н', '3Н'].include?(b[:room])
        dops = 1
      elsif b[:room] != '1Н'
        dops = 3
      end
    else
      dops = 3
    end
  elsif b[:cat] == :poorlux2k
    dops = 2
  end

  dops.times do
    n = b.clone
    n[:dop] = true
    all_beds.push(n)
  end
end

extra.each_pair do |k, v|
  if not v.empty?
    raise "In extra, for building #{k} these rooms are not found: #{v}"
  end
end

def cat_index(d)
  cat_order = [
    :standard,
    :comfort,
    :comfort1b,
    :econom,
    :lux,
    :poorlux,
    :poorlux2k,
    :family,
  ]

  i = cat_order.index(d[:cat])
  raise "Can not find index" if not i
  i
end

def room_name(d)
  n = "#{d[:build]} - #{d[:room]}"
  n += " д" if d[:dop]
  n
end

def comfort_build(d)
  b = d[:build].to_i
  return -1 if b == 4
  b
end

def order(a, b)
   d = cat_index(a) <=> cat_index(b)
   return d if d != 0
   d = a[:beds] <=> b[:beds]
   return d if d != 0
   if [:comfort, :comfort1b, :poorlux2k].include?(a[:cat])
     d = comfort_build(a) <=> comfort_build(b)
   else
     d = a[:build] <=> b[:build]
   end
   return d if d != 0
   return a[:room].to_i <=> a[:room].to_i
end

all_beds.sort! { |a, b| order(a, b) }

res = []
all_beds.each do |d|
  name = room_name(d)
  cat = cats[d[:cat]]
  bedsname = bednames[d[:beds]]
  dop = d[:dop] ? "Допместо" : ""
  res.push([name, cat, bedsname, dop].join(','))
end

res.each { |l| puts l }
