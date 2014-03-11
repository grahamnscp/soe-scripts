#!/usr/bin/ruby
#
# Includes
require 'rubygems'
require 'xmlrpc/client'

#
# Satelite connection parameters
sathost = "satellite.my-domain.com"
satapipath = "/rpc/api"
@satuser = "myadmin"
satpwd = "password"
@orgid = String.new
@orgname = "MyDomainSubOrgName" # Can't find this in the suborg and need satadmin to access org.getDetails(org_id) !
#
# Globals
@satconn = XMLRPC::Client.new(sathost,satapipath,nil,nil,nil,nil,nil,'https',90)
@satconn2 = XMLRPC::Client.new(sathost,satapipath,nil,nil,nil,nil,nil,'https',90)
@satsession = @satconn.call('auth.login',@satuser,satpwd)
@satsession2 = @satconn2.call('auth.login',@satuser,satpwd)


#
# function: populate_org_id
#
def populate_org_id

  api = "user.getDetails"

  ok, result = @satconn.call2_async(api,@satsession,@satuser)

  if ok
    @orgid = result['org_id'].to_s
    puts "org_id is " + @orgid
  else
    puts "populate_org_id: API Call Failed: " + result
    p result = @satconn.call_async(api,@satsessioni,@satuser)
    exit
  end
end


#
# function: populate_org_name
#
def populate_org_name

  api = "org.getDetails"

  ok, result = @satconn.call2_async(api,@satsession,2)

  if ok
    @orgname = result['org_name'].to_s
    puts "org_name is " + @orgname
  else
    puts "populate_org_name: API Call Failed: " + result
    p result = @satconn.call_async(api,@satsession,2)
    exit
  end
end


#
# function: read_systems
#
def read_systems

  systems = Array.new
  ret_entry = Hash.new

  ok, result = @satconn.call2_async("system.listActiveSystems",@satsession)

  if ok
    result.each do |entry|
      ret_entry['name'] = entry['name']
      ret_entry['id'] = entry['id']
      systems.push ret_entry
    end
  else
    puts "read_systems: API Call Failed: " + result
    exit
  end
  return systems
end


#
# function: read_channels
#
def read_channels api

  if !api then api="channel.listAllChannels"  end
  channels = Array.new
  ok, result = @satconn.call2_async(api,@satsession)

  if ok
    result.each do |entry|
      channels.push entry['label']
    end
  else
    puts "read_channels: API Call Failed: " + result
    p result = @satconn.call_async(api,@satsession)
    exit
  end
  return channels
end


#
# function: read_base_channels
#
def read_base_channels system

  channels = Array.new

  api = "system.listSubscribableBaseChannels"
  result = @satconn2.call(api,@satsession2,system)
  result.each do |entry|
    channels.push entry['label']
  end

  return channels
end


#
# function: read_sub_channels
#
def read_sub_channels system

  channels = Array.new

  api ="system.listSubscribedChildChannels"
  result = @satconn2.call(api,@satsession2,system)
  result.each do |entry|
    channels.push entry['label']
  end

  api = "system.listSubscribableChildChannels"
  result = @satconn2.call(api,@satsession2,system)
  result.each do |entry|
    channels.push entry['label']
  end
 
  return channels
end


#
# function: read_activationkeys
#
def read_activationkeys

  api = "activationkey.listActivationKeys"
  actkeys = Array.new

  ok, result = @satconn.call2_async(api,@satsession)

  if ok
    result.each do |entry|
      actkeys.push entry['key']
    end
  else
    puts "read_activationkeys: API Call Failed: " + result
    p result = @satconn.call_async(api,@satsession)
    exit
  end
  return actkeys
end


#
# function: read_kickstarts
#
def read_kickstarts

  api = "kickstart.listKickstarts"
  kickstarts = Array.new

  ok, result = @satconn.call2_async(api,@satsession)

  if ok
    result.each do |entry|
      kickstarts.push entry['label']+":"+@orgid+":"+@orgname
    end
  else
    puts "read_kickstarts: API Call Failed: " + result
    p result = @satconn.call_async(api,@satsession)
    exit
  end
  return kickstarts
end



#
# Main
#
BEGIN { $VERBOSE = nil }

puts "Satellite API Version: " + @satconn.call_async('api.getVersion')

populate_org_id
#populate_org_name
puts "org_name = " + @orgname

puts
puts "All Channel Labels: "
channels = read_channels nil
channels.each do |entry|
  puts "\t" + entry
end

puts
puts "All ActivationKey Labels: "
akeys = read_activationkeys
akeys.each do |entry|
  puts "\t" + entry
end

puts
puts "All Kickstart Labels: "
kickstarts = read_kickstarts
kickstarts.each do |entry|
  puts "\t" + entry
end

puts
puts "Active systems: "
systems = read_systems

systems.each do |entry|
  puts "  System: " + entry['name'] + ", " + entry['id'].to_s
  
  puts "     Available Base Channel Labels: "
  channels = read_base_channels entry['id']
  channels.each do |channel|
    puts "\t" + channel
  end

  puts "     Available Child Channel Labels: "
  channels = read_sub_channels entry['id']
  channels.each do |channel|
    puts "\t" + channel
  end
end

