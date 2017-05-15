require 'net/http'
require 'json'
require 'erb'

module Studont
  CACHE_RECORD_TYPE = [
    CACHE_RECORD_NOT_ON_LOCAL_TIMELINE = 0,
    CACHE_RECORD_NOT_ON_FED_TIMELINE = 1,
    CACHE_RECORD_ERROR = 2,
    CACHE_RECORD_STORED = 3,
  ]

  CACHE_RECORD = Struct.new(:type, :status)

  class Error < StandardError
  end

  class HttpError < Error
    attr_reader :inner_error

    def initialize(inner_error)
      @inner_error = inner_error
    end
  end

  class Instance
    def initialize(host)
      @host = host
      @cache = Hash.new
    end

    def timeline(local: true, newest: nil, oldest: nil)
      Timeline.new(instance: self, local: local, newest: newest, oldest: oldest)
    end

    def public_timeline_chunk(local: true, from_id: nil)
      if from_id
        cached = @cache[from_id]
        while cached
          return [cached.status] if cached.type == CACHE_RECORD_STORED && (!local || local_status?(cached.status))
          break if !local && cached.status == CACHE_RECORD_NOT_ON_LOCAL_TIMELINE
          from_id -= 1
          cached = @cache[from_id]
        end
      end

      query_params = {}
      query_params['max_id'] = from_id + 1 if(from_id)
      query_params['local'] = 1 if (local)
      uri = build_uri(URI_TIMELINES_PUBLIC, query_params: query_params)
      statuses = perform_request(uri)
      update_cache(statuses, local: local, expected_max_id: from_id ? from_id + 1 : nil)

      statuses.sort_by { |status| status['id'] }.reverse
    end

    private

    URI_TIMELINES_PUBLIC = ERB.new('https://<%= @host %>/api/v1/timelines/public')
    private_constant :URI_TIMELINES_PUBLIC

    def build_uri(uri_template, path_params: {}, query_params: {})
      uri = URI(uri_template.result(binding))
      clean_params = query_params.reject { |name, val| val.nil? }
      uri.query = URI.encode_www_form(clean_params) if clean_params.any?
      uri
    end

    def perform_request(uri)
      begin
        puts "Requesting #{uri}" if ENV['DEBUG']
        statuses_string = Net::HTTP.get(uri)
      rescue StandardError => e
        STDERR.puts e if ENV['DEBUG']
        raise HttpError.new(e)
      end
      JSON.parse(statuses_string)
    end

    def local_status?(status)
      status['account']['username'] == status['account']['acct']
    end

    def update_cache(statuses, local:, expected_max_id: nil, mark_gaps: true)
      return unless statuses

      prev_id = expected_max_id + 1 if expected_max_id
      statuses.sort_by { |status| status['id'] } .reverse.each do |status|
        status_id = status['id']
        if mark_gaps && prev_id
          (status_id+1...prev_id). each do |id|
            cached = @cache[id]
            if cached.nil?
              @cache[id] = CACHE_RECORD.new(local ? CACHE_RECORD_NOT_ON_LOCAL_TIMELINE : CACHE_RECORD_NOT_ON_FED_TIMELINE)
            elsif !local && cached.type == CACHE_RECORD_NOT_ON_LOCAL_TIMELINE
              @cache[id].type = CACHE_RECORD_NOT_ON_FED_TIMELINE
            end
          end
        end
        @cache[status_id] = CACHE_RECORD.new(CACHE_RECORD_STORED, status)
        prev_id = status_id
      end
    end
  end
end
