# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

DAYNAMES = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]

def clean_zipcodes(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(phone_number)
  phone_number.gsub!(/[()\-,. ]/, '')
  if phone_number.length < 10
    "Bad Number"
  elsif phone_number.length == 11
    if phone_number[0] != 1
      "Bad Number"
    else
      phone_number[1..10]
    end
  else
    phone_number
  end
end

def clean_registration_dates(reg_date)
  Time.strptime(reg_date,"%m/%d/%y %H:%M").hour
end

def get_day_of_week(reg_date)
  DAYNAMES[Date.strptime(reg_date, "%m/%d/%y %H:%M").wday]
end

def find_peak_reg_day(peak_days, reg_day)
  if peak_days.key?(reg_day)
    peak_days[reg_day] += 1
  else
    peak_days[reg_day] = 1
  end
end

def find_peak_registration_times(peak_times, reg_date)
  if peak_times.key?(reg_date)
    peak_times[reg_date] += 1
  else
    peak_times[reg_date] = 1
  end
end

def best_ad_day(peak_days)
  peak_days.sort_by { |_k, v| v }
end

def prime_advertising_hours(peak_times)
  peak_times.sort_by { |_k, v| v }
end

def best_days_and_hours(peak_times, peak_days)
  "The best times to run ads are #{prime_advertising_hours(peak_times)[-1][0]}:00 and #{prime_advertising_hours(peak_times)[-2][0]}:00 on #{best_ad_day(peak_days)[-1][0]}"
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
peak_times = {}
peak_days = {}

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcodes(row[:zipcode])

  phone_number = clean_phone_numbers(row[:homephone])

  reg_date = clean_registration_dates(row[:regdate])
  reg_day = get_day_of_week(row[:regdate])
  peak_time = find_peak_registration_times(peak_times, reg_date)
  peak_day = find_peak_reg_day(peak_days, reg_day)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  puts "#{name} #{phone_number} #{reg_date}"
end

puts best_days_and_hours(peak_times, peak_days)

