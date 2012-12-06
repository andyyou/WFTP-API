require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'gd2-ffij'
include GD2

get '/get-image' do
	full_path = "images/" + params[:f].to_s
	send_file full_path.to_s, :type => 'image/jpeg', :disposition => 'inline'
end

get '/thumb' do
	path = params[:p].to_s
	default_width = 120
	default_height = 120
	limit_format = %w{jpg png gif jpeg bmp}
	format = path.split(".").last
	
	return "No Image" if !limit_format.include? format
		 
	digest = Digest::MD5.hexdigest(path)
	cachefile = "images_cache/" + digest + "." + format
	if File.exists?(cachefile) && (File.stat(cachefile).mtime.to_i > File.stat(path).mtime.to_i)
		thumb_source = cachefile
		cache = true
	elsif File.exists?(path)
		thumb_source = path
	end
	
	if cache == true
		send_file thumb_source, :type => 'image/jpeg', :disposition => 'inline'
	else
		puts thumb_source
		i = Image.import(thumb_source)	 
		
		if i.width > i.height # Horizontal proportion. width > height
			if i.width < default_width then width = i.width
			else width = default_width
			end
			
			height = width * i.height / i.width
		else
			if i.height < default_height then height = i.height
			else height = default_height
			end
			
			width = i.width / (i.height/height)
		end
		
		i.resize! width, height
		if format == "gif" then @thumb = i.gif
		elsif format == "png" then @thumb = i.png
		else @thumb = i.jpeg 80
		end
		i.export(cachefile) # export cache file
		send_file cachefile.to_s, :type => 'image/jpeg', :disposition => 'inline'
	end
	
end

