require 'date'

def parse(curr_line, idx)

  puts '* Parsing line start.'
  puts "curr_line: #{curr_line}"

  first, rest = curr_line.chomp.split('# ', 2)
  puts "first=[#{first}], rest=[#{rest}]"

  # TODO: add line format validation

  date_str, rest = rest.split(', ', 2)
  puts "date_str=[#{date_str}], rest=[#{rest}]"

  week_day, rest = rest.split(', ', 2) if rest != nil
  puts "week_day: #{week_day}, rest=[#{rest}]"

  hour_from, rest = rest.split('/', 2) if rest != nil # && rest.^(?!.*dog).*$
  puts "hour_from=[#{hour_from}], rest=[#{rest}]"

  hour_to, rest = rest.split(', ', 2) if rest != nil
  puts "hour_to=[#{hour_to}], rest=[#{rest}]"

  raise "incorrect file format, priv section must be before hours section, line #{idx}" if rest && rest =~/^.*hours.*priv.*$/

  priv, rest = rest.split(', ', 2) if rest != nil && rest.include?('priv')
  if priv != nil
    priv_str = priv != nil ? priv.sub(/priv: /, '') : '0.0'
    # puts "priv_str: [#{priv_str}]"
    raise "incorrect value for priv [#{priv_str}, line #{idx}" unless priv_str =~/(\d*)([.]\d+){0,1}/
    priv = priv_str.to_f
    # puts "priv_str.to_f=[#{priv}]"
  else
    priv = 0.0
  end
  puts "priv=[#{priv}], rest=[#{rest}]"

  old_hours, rest = rest.split(', ', 2) if rest != nil && rest.include?('hours')
  if old_hours != nil
    old_hours_str = old_hours != nil ? old_hours.sub(/hours: /, '') : '0.0'
    # puts "old_hours_str=[#{old_hours_str}]"
    raise "incorrect value for old_hours [#{old_hours_str}, line #{idx}" unless old_hours_str =~/(-*)(\d*)([.]\d)*/
    old_hours = old_hours_str.to_f
    # puts "old_hours_str.to_f=[#{old_hours}]"
  end
  puts "old_hours=[#{old_hours}], rest=[#{rest}]"

  # TODO: would be nice to document what are those expected hours
  expected, rest = rest.split(', ', 2) if rest != nil && rest.include?('expected')
  if expected != nil
    expected_str = expected != nil ? expected.sub(/expected: /, '') : '0.0'
    puts "expected_str=[#{expected_str}]"
    raise "incorrect value for expected [#{expected}], line #{idx}" unless expected_str =~ /(-*)(\d*)([.]\d)*/
    expected = expected_str.to_f
    puts "expected_str.to_f=[#{expected}]"
  end
  puts "expected=[#{expected}], rest=[#{rest}]"

  puts '* Parsing line end.'
#   puts '-------------------------------------------------'
  return date_str, week_day, hour_from, hour_to, priv, old_hours, expected
end

def validate(year)
  input_text=File.open("#{year}.md").read
  date_str, week_day, hour_from, hour_to, old_hours = ''
  idx = 1
  input_text.each_line do |line|
    puts "---> line: #{idx}"
    if is_overtime(line)
      date_str, weekday, hour_from, hour_to, priv, old_hours, expected = parse(line, idx)
      raise "date_str [#{date_str}] is invalid (line: #{idx})" unless valid_date?(date_str)
      raise "hour_from [#{hour_from}] is invalid (line: #{idx})" unless valid_hour?(hour_from)
      raise "hour_to [#{hour_to}] is invalid (line: #{idx})" unless valid_hour?(hour_to)
      raise "line #{idx} contains string that match following regular expression: \d{2}:\d{2} \d{2}:\d{2}" if line =~/\d{2}:\d{2} \d{2}:\d{2}/
    elsif
      "Line #{idx} don't match overtime pattern. Skipping"
    end
    idx += 1
  end
  "File #{year}.md is valid"
end

def valid_date?(str, format='%Y-%m-%d')
  Date.strptime(str, format) rescue false
end

def valid_hour?(str, format=/\d{2}:\d{2}/)
  str =~ format
end

def is_overtime(line)
  line.start_with?('#') && !line.include?('WOLNE') && !line.include?('URLOP') && !line.include?('TIMESHEET')
end

def overtime(year)
  overtime_hours = 0.0
  my_hours = 0.0
  input_text = File.open("#{year}.md").read
  # date_str, week_day, hour_from, hour_to, old_hours = ''
  idx = 1
  input_text.each_line do |line|
    puts "---> Line #{idx} : #{line}"
    if is_overtime(line)
      date_str, week_day, hour_from, hour_to, priv, old_hours, expected = parse(line, idx)
      dt1 = DateTime.parse("#{date_str} #{hour_from}:00")
      dt2 = DateTime.parse("#{date_str} #{hour_to}:00")
      puts "dt1=[#{dt1}], dt2=[#{dt2}]"
      total_hours = (dt2.to_time - dt1.to_time) / 3600
      puts "Total Hours in current day: #{total_hours}"
      # TODO: would be nice to explain why is expected for?
      # maybe it's in case to adjust initial hours at the beginning of perid (year)
      puts "Expected Hours: #{expected}"
      curr_day_expected = expected ? expected : 8.0
      puts "Current day expected #{curr_day_expected}"
      puts "Private hours: #{priv}"
      curr_day_overtime = total_hours - curr_day_expected - priv
      # undertime < 0 < overtime
      puts "Current day over(under)time: #{curr_day_overtime}"
      # wyliczone godziny na dany dzien = oczekiwane w danym dniu + nadgodziny
      # (ujemne nadgodziny to czas do odrobienia)
      curr_day_hours = curr_day_expected + curr_day_overtime
      puts "hour_from: #{hour_from}, hour_to: #{hour_to}, total_hours: #{total_hours}, priv: #{priv}, curr_day_hours: #{curr_day_hours}, curr_day_overtime: #{curr_day_overtime}"
      overtime_hours += curr_day_overtime
      puts "curr_day_overtime=[#{curr_day_overtime}]"
      puts "overtime_hours=[#{overtime_hours}]"
      my_hours = old_hours if old_hours != nil
      raise "my_hours [#{my_hours}] is different than overtime_hours [#{overtime_hours}], (file: E:/hopbit/dev/workspace/ruby/apps/timesheetrb/#{year}.md:#{idx} )" if overtime_hours != my_hours
    end
    idx += 1
  end
  puts "overtime_hours=[#{overtime_hours}]"
  overtime_hours
end

# parse command line args
command = ARGV[0]
puts "command=[#{command}]"
raise "Incorrect command (arg0): [#{command}]" unless command
year = ARGV[1]
raise "Incorrect year (arg1): [#{year}]" unless year
puts "year=[#{year}]"
month = ARGV[2]
puts "month=[#{month}]"
day = ARGV[3]
puts "day=[#{day}]"

# do chosen command
result = nil
if '0' == command
  result = validate(year)
elsif '1' == command
  result = overtime(year)
end

# show result
puts "Result: #{result}"
