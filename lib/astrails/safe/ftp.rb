module Astrails
  module Safe
    class Ftp < Sink

      protected

      def active?
        host && user
      end

      def path
        @path ||= expand(config[:sftp, :path] || config[:local, :path] || ":kind/:id")
      end

      def save
        raise RuntimeError, "pipe-streaming not supported for FTP." unless @backup.path

        puts "Uploading #{host}:#{full_path} via FTP" if $_VERBOSE || $DRY_RUN

        unless $DRY_RUN || $LOCAL
          opts = {}
          opts[:password] = password if password
          opts[:port] = port if port

          Net::FTP.open(host) do |ftp|
            ftp.login(user, password)

			      puts "Sending #{@backup.path} to #{full_path}" if $_VERBOSE
			      retries = 0

			      begin
			        ftp.putbinaryfile @backup.path, full_path
			      rescue Net::FTPError
			        if retries > 0
			          raise
			        end
			
			        puts "Ensuring remote path (#{path}) exists" if $_VERBOSE
			        # mkdir -p
			        folders = path.split('/')
			        folders.each_index do |i|
			          folder = folders[0..i].join('/')
			          puts "Creating #{folder} on remote" if $_VERBOSE
			          ftp.mkdir(folder) rescue Net::FTPError
			        end
			        
			        retries += 1
			        retry
			      end
			    end
          puts "...done" if $_VERBOSE
        end
      end

      def cleanup
        return if $LOCAL || $DRY_RUN

        return unless keep = @config[:keep, :ftp]

        puts "listing files: #{host}:#{base}*" if $_VERBOSE
        opts = {}
        opts[:password] = password if password
        opts[:port] = port if port

        Net::FTP.open(host) do |ftp|
	        ftp.login(user, password)

          files = ftp.chdir(path)
          files = ftp.list( File.basename("#{base}*") )
        
          puts files.collect {|x| x.name } if $_VERBOSE
        	
          files = files.
                      	collect {|x| x.name }.
                      	sort	

	        cleanup_with_limit(files, keep) do |f|
	          file = File.join(path, f)
	          puts "removing ftp file #{host}:#{file}" if $DRY_RUN || $_VERBOSE
	          ftp.delete(file) unless $DRY_RUN || $LOCAL
	        end
        end
      end

      def host
        @config[:ftp, :host]
      end

      def user
        @config[:ftp, :user]
      end

      def password
        @config[:ftp, :password]
      end

      def port
        @config[:ftp, :port]
      end

    end
  end
end