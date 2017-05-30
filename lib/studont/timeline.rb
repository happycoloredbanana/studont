# frozen_string_literal: true

require 'date'

module Studont
  class Timeline
    include Enumerable

    def initialize(instance, local: true, newest: nil, oldest: nil)
      @instance = instance
      @local = local
      @newest_date, @newest_id = prepare_id_date_param(newest)
      @oldest_date, @oldest_id = prepare_id_date_param(oldest)
    end

    def each
      return enum_for(:each) unless block_given?

      last_id = nil
      if @newest_date
        last_id = find_id_for_date_time(@newest_date)
        return if last_id.nil?
      elsif @newest_id
        last_id = @newest_id + 1
      end

      loop do
        statuses = @instance.public_timeline_chunk(
          local: @local,
          from_id: last_id ? last_id - 1 : nil
        )
        prev_last_id = last_id
        statuses.each do |status|
          next unless status['id']
          break if @oldest_id && @oldest_id > status['id']
          created_at = status['created_at']
          break if @oldest_date && created_at &&
                   DateTime.parse(created_at) < @oldest_date
          yield status if (@newest_date.nil? || created_at.nil? ||
                          DateTime.parse(created_at) <= @newest_date) &&
                          (@newest_id.nil? || status['id'] <= @newest_id)
          last_id = status['id']
        end
        return if prev_last_id == last_id
      end
    end

    private

    def parse_to_datetime(str)
      DateTime.parse(str)
    rescue ArgumentError, TypeError
      nil
    end

    def prepare_id_date_param(param)
      result = [nil, nil]
      if param
        result[0] =
          if param.class == DateTime
            param
          else
            parse_to_datetime(param)
          end
        result[1] = param.to_i unless result[0]
      end

      result
    end

    def find_id_for_date_time(date)
      statuses = @instance.public_timeline_chunk(local: true)
      return nil if statuses.empty?

      first_created_at = DateTime.parse(statuses.first['created_at'])
      return statuses[0]['id'] + 1 if date >= first_created_at

      newest = statuses[0]
      newest_id = newest['id']
      oldest = nil
      oldest_id = 1

      while DateTime.parse(newest['created_at']) > date &&
            (oldest.nil? || date >= DateTime.parse(oldest['created_at']))
        middle_id = (newest_id + oldest_id) / 2
        return newest['id'] if middle_id == newest_id || middle_id == oldest_id

        statuses = @instance.public_timeline_chunk(local: true,
                                                   from_id: middle_id)
        if statuses.empty?
          oldest = nil
          oldest_id = middle_id
        elsif DateTime.parse(statuses[0]['created_at']) <= date
          return newest['id'] if oldest_id == statuses[0]['id']
          oldest = statuses[0]
          oldest_id = oldest['id']
        else
          return newest['id'] if newest_id == statuses[0]['id']
          newest = statuses[0]
          newest_id = newest['id']
        end
      end

      nil
    end
  end
end
