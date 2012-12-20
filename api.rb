# encoding: UTF-8
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'RMagick'
require 'mimemagic'
require 'fileutils'
require 'tiny_tds'
require 'find'

# Authorization information
$apiKey = "15eb7a42cce1ab9822caa1f8aaa65a494d38d19654886e67c0a6b15edcdcfde7"
# FTP information
$ftpRootPath = "/home/wintriss/admin/engineer/WFTP"
$ftpTrashPath = "/home/wintriss/admin/engineer/WFTP/Trash"
# Database information
$dbHost = "192.168.100.248"
$dbUsername = "sa"
$dbPassword = "apputu.SQL"
$dbTableName = "WFTP"

def CheckAccessibility (key)
	if (key == $apiKey)
		return true
	end
end

get '/check' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
	if File.exist?("#{$ftpRootPath}#{params[:p]}")
		return "true"
	else
		return "false"
	end
end

get '/checkrename' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil? || params[:n].nil?
	if File.exist?("#{$ftpRootPath}#{params[:p]}")
		return "true" if params[:p] == params[:n]
                newPath = "#{$ftpRootPath}#{params[:n]}"
                if File.exists?(newPath)
                        return "false"
                else
                        return "true"
                end
        else
                return "false"
        end	
end

get '/getsize' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
        if File.exist?("#{$ftpRootPath}#{params[:p]}")
                return File.size("#{$ftpRootPath}#{params[:p]}").to_s
        end
end

get '/dir' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
	if File.exist?("#{$ftpRootPath}#{params[:p]}")
		return Dir.glob("#{$ftpRootPath}#{params[:p]}*").join(",").gsub($ftpRootPath, "")
	end
end

get '/mkdir' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
	if !File.exist?("#{$ftpRootPath}#{params[:p]}")
		Dir.mkdir("#{$ftpRootPath}#{params[:p]}")
		File.chmod(0777, "#{$ftpRootPath}#{params[:p]}")

		return "true"
	else
		return "false"
	end
end

get '/rmdir' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
	if File.exist?("#{$ftpRootPath}#{params[:p]}") && File.writable?("#{$ftpRootPath}#{params[:p]}")
		trashRelativePath = params[:p][0, params[:p].rindex('/')]

		if !File.exist?("#{$ftpTrashPath}#{trashRelativePath}")
			FileUtils.mkdir_p("#{$ftpTrashPath}#{trashRelativePath}")
			File.chmod(0777, "#{$ftpTrashPath}#{trashRelativePath}")
			FileUtils.mv("#{$ftpRootPath}#{params[:p]}", "#{$ftpTrashPath}#{trashRelativePath}")
		else
			FileUtils.cp_r("#{$ftpRootPath}#{params[:p]}", "#{$ftpTrashPath}#{trashRelativePath}")
		end

		FileUtils.rm_rf("#{$ftpRootPath}#{params[:p]}")

		return "true"
	else
		return "false"
	end
end

get '/rename' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil? || params[:n].nil?
	if File.exist?("#{$ftpRootPath}#{params[:p]}") && File.writable?("#{$ftpRootPath}#{params[:p]}")
		return "true" if params[:p] == params[:n]
		newPath = "#{$ftpRootPath}#{params[:n]}"
		if File.exists?(newPath)
			return "false"
		else
			FileUtils.mv("#{$ftpRootPath}#{params[:p]}", newPath)

			return "true"
		end
	else
		return "false"
	end
end

get '/deletefile' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
	if File.exist?("#{$ftpRootPath}#{params[:p]}")
		FileUtils.rm_f("#{$ftpRootPath}#{params[:p]}")

		return "true"
	else
		return "false"
	end
end

get '/thumb'do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
	path = "#{$ftpRootPath}#{params[:p]}"
	return if !File.exist?(path)
	width, height = 120, 120
	limit_extension = %w{jpg jpeg png gif tif bmp}
        extension = path.split(".").last
	mime = MimeMagic.by_extension(extension).to_s

	return "No Image" if !limit_extension.include? extension

	digest = Digest::MD5.hexdigest(path)
        cachefile = "images_cache/" + digest + "." + extension
        if File.exists?(cachefile) && (File.stat(cachefile).mtime.to_i > File.stat(path).mtime.to_i)
                thumb_source = cachefile
                cache = true
        elsif File.exists?(path)
                thumb_source = path
        end

	if cache == true
                send_file thumb_source, :type => mime, :disposition => 'inline'
        else
		img =  Magick::Image.read(thumb_source).first
		thumb = img.resize_to_fit(width, height)

		thumb.write(cachefile)
		send_file cachefile.to_s, :type => mime, :disposition => 'inline'
	end
end

get '/getfoldercount' do
	splitPath = params[:p].split('/').reject(&:empty?)
	level = splitPath.count

	# Combination SQL command -- Start
	entityPath = "/#{splitPath[0]}"
	sqlSelect = "T2.[CompanyName] AS Name"
	sqlFrom = "[WFTP].[dbo].[Lv1Classifications] T1
                   , [WFTP].[dbo].[Lv2Customers] T2"
	sqlCondition = "T1.[ClassName] = '#{splitPath[0]}' AND T2.[ClassifyId] = T1.[ClassifyId]"

	if level >= 2
		entityPath = "#{entityPath}/#{splitPath[1]}"
		sqlSelect = "T3.[BranchName] AS Name"
		sqlFrom = sqlFrom + ", [WFTP].[dbo].[Lv3CustomerBranches] T3"
		sqlCondition = sqlCondition + "AND T2.[CompanyName] = '#{splitPath[1]}' AND T3.[CompanyId] = T2.[CompanyId]"
	end

	if level >= 3
		entityPath = "#{entityPath}/#{splitPath[2]}"
		sqlSelect = "T4.[LineName] AS Name"
		sqlFrom = sqlFrom + ", [WFTP].[dbo].[Lv4Lines] T4"
		sqlCondition = sqlCondition + "AND T3.[BranchName] = '#{splitPath[2]}' AND T4.[BranchId] = T3.[BranchId]"
	end

	if level > 4
		entityPath = "#{entityPath}/#{splitPath[3]}/#{splitPath[4]}"
		sqlSelect = "T6.[FileName] As Name"
		sqlFrom = sqlFrom + ", [WFTP].[dbo].[FileCategorys] T5, [WFTP].[dbo].[Files] T6"
		sqlCondition = sqlCondition + "AND T5.[ClassName] = '#{splitPath[4]}' AND T4.[LineName] = '#{splitPath[3]}' AND T6.[LineId] = T4.[LineId] AND T6.[FileCategoryId] = T5.[FileCategoryId]"
	end
	# Combination SQL command -- End

	existDir = Dir.glob("#{$ftpRootPath}#{entityPath}/*").map { |directory| directory.gsub!("#{$ftpRootPath}#{entityPath}/", "") }

	client = TinyTds::Client.new(:username => $dbUsername, :password => $dbPassword, :host => $dbHost, :database => $dbTableName)
	result = client.execute("SELECT #{sqlSelect} FROM #{sqlFrom} WHERE #{sqlCondition}")

	count = 0
	result.each { |row|
		count = count + 1 if existDir.include?(row["Name"].encode("UTF-8", "BIG5"))
	}
	return count.to_s
end

get '/createcategorys' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:p].nil?
	if File.exist?("#{$ftpRootPath}#{params[:p]}") && File.writable?("#{$ftpRootPath}#{params[:p]}")
		client = TinyTds::Client.new(:username => $dbUsername, :password => $dbPassword, :host => $dbHost, :database => $dbTableName)
		result = client.execute("SELECT [ClassName] FROM [WFTP].[dbo].[FileCategorys]")
		result.each { |category|
			folderName = category["ClassName"]
			if !File.exist?("#{$ftpRootPath}#{params[:p]}/#{folderName}")
				Dir.mkdir("#{$ftpRootPath}#{params[:p]}/#{folderName}")
				File.chmod(0777, "#{$ftpRootPath}#{params[:p]}/#{folderName}")
			end
		}
                return "true"
        else
                return "false"
        end
end

get '/addcategory' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:n].nil?
	paths = Array.new
	Find.find($ftpRootPath) do |path|
		if path.match(/WFTP\/[\w ]+\/[\w ]+\/[\w ]+\/[\w ]+\//) && !path.match("/WFTP\/Trash/")
			newPath = path[/#{$ftpRootPath}\/[\w ]+\/[\w ]+\/[\w ]+\/[\w ]+\//] + params[:n]
			if !File.exist?(newPath)
				paths.push(newPath)
			end
		end
	end
	# remove duplicate elements from array
	paths.uniq!
	paths.each do |path|
		Dir.mkdir(path)
		File.chmod(0777, path)
	end
	return "true"
end

get '/renamecategorys' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:n].nil? || params[:nn].nil?
	return "0" if params[:n] == params[:nn]
	matchCount = 0
	Find.find($ftpRootPath) do |path|
		if path.match(/WFTP\/[\w ]+\/[\w ]+\/[\w ]+\/[\w ]+\/#{params[:n]}$/)
			matchCount = matchCount + 1
			newPath = path[0, path.rindex(params[:n])] + params[:nn]
			if File.exists?(newPath)
				return "-1"
			else
				FileUtils.mv(path, newPath)
			end
		end
	end
	return matchCount.to_s
end

get '/removecategorys' do
	return "Access Denied!" if !CheckAccessibility params[:key]
	return "false" if params[:n].nil?
	matchCount = 0
	Find.find($ftpRootPath) do |path|
                if path.match(/WFTP\/[\w ]+\/[\w ]+\/[\w ]+\/[\w ]+\/#{params[:n]}$/)
			matchCount = matchCount + 1
			oldPath = path.gsub($ftpRootPath, "")
			trashRelativePath = oldPath[0, oldPath.rindex('/')]

			if !File.exist?("#{$ftpTrashPath}#{trashRelativePath}")
				FileUtils.mkdir_p("#{$ftpTrashPath}#{trashRelativePath}")
				File.chmod(0777, "#{$ftpTrashPath}#{trashRelativePath}")
				FileUtils.mv(path, "#{$ftpTrashPath}#{trashRelativePath}")
			else
				FileUtils.cp_r(path, "#{$ftpTrashPath}#{trashRelativePath}")
			end

			FileUtils.rm_rf(path)
		end
	end
	return matchCount.to_s
end
