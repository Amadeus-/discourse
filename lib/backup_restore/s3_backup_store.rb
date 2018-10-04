require_dependency "backup_restore/backup_store"

module BackupRestore
  class S3BackupStore < BackupStore
    DOWNLOAD_URL_EXPIRES_AFTER_SECONDS = 15
    UPLOAD_URL_EXPIRES_AFTER_SECONDS = 21600 # 6 hours

    def initialize
      @s3_helper ||= S3Helper.new(SiteSetting.s3_backup_bucket, '', S3Helper.s3_options(SiteSetting))
    end

    def remote?
      true
    end

    def file(filename, include_download_source: false)
      obj = @s3_helper.s3_bucket.object(filename)
      create_file_from_object(obj, include_download_source) if obj.exists?
    end

    def delete_file(filename)
      obj = @s3_helper.s3_bucket.object(filename)
      obj.delete if obj.exists?
    end

    def download_file(filename, destination_path, failure_message = nil)
      unless @s3_helper.s3_bucket.object(filename).download_file(destination_path)
        raise failure_message.presence&.to_s || "Failed to download file"
      end
    end

    def upload_file(filename, source_path, content_type)
      obj = @s3_helper.s3_bucket.object(filename)
      raise BackupFileExists.new if obj.exists?

      obj.upload_file(source_path, content_type: content_type)
    end

    def generate_upload_url(filename)
      obj = @s3_helper.s3_bucket.object(filename)
      raise BackupFileExists.new if obj.exists?

      presigned_url(obj, :put, UPLOAD_URL_EXPIRES_AFTER_SECONDS)
    end

    protected

    def unsorted_files
      @s3_helper.list.map { |obj| create_file_from_object(obj) }
    end

    private

    def create_file_from_object(obj, include_download_source = false)
      BackupFile.new(
        filename: obj.key,
        size: obj.size,
        last_modified: obj.last_modified,
        source: include_download_source ? presigned_url(obj, :get, DOWNLOAD_URL_EXPIRES_AFTER_SECONDS) : nil
      )
    end

    def presigned_url(obj, method, expires_in_seconds)
      obj.presigned_url(method, expires_in: expires_in_seconds)
    end
  end
end
