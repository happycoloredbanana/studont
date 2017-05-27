require 'json'
require 'spec_helper'

def filter_statuses(statuses, request)
  max_id = request.uri.query_values['max_id']&.to_i
  since_id = request.uri.query_values['since_id']&.to_i
  JSON.generate(
    statuses.select { |status| (max_id.nil? || status['id'] < max_id) &&
      (since_id.nil? || status['id'] > since_id) }
  );
end

RSpec.describe Studont::Instance do
  let(:host) { 'mastodon.example.com' }
  let(:instance) { Studont::Instance.new(host) }
  let(:status1) { { 'id' => 2, 'account' => {'username' => 'user', 'acct' => 'user' } } }
  let(:status2) { { 'id' => 3, 'account' => {'username' => 'user', 'acct' => 'user' } } }
  let(:status3) { { 'id' => 6, 'account' => {'username' => 'user', 'acct' => 'user' } } }
  request_stub = nil

  context 'when local timeline' do
    before(:each) do
      request_stub = stub_request(:get, %r"^https://#{host}/api/v1/timelines/public\?local=1").to_return(
        body: lambda { |request| filter_statuses([status3, status2, status1], request) } )
    end

    it 'returns nothing when nothing is retrieved' do
      request_stub =stub_request(:get, %r"https://#{host}/api/v1/timelines/public\?local=1.*").to_return(
        body: lambda { |request| filter_statuses([], request) } )

      chunk = instance.public_timeline_chunk
      expect(chunk).to be_empty
      expect(request_stub).to have_been_requested.times(1)
    end

    it 'returns nothing when from_id is set and nothing is retreived' do
      request_stub = stub_request(:get, %r"^https://#{host}/api/v1/timelines/public\?local=1").to_return(
        body: lambda { |request| filter_statuses([], request) } )

      chunk = instance.public_timeline_chunk(from_id: 10)
      expect(chunk).to be_empty
      expect(request_stub).to have_been_requested.times(1)
    end

    it 'returns statuses with ids less than from_id when status with id==from_id is missing' do
      chunk = instance.public_timeline_chunk(from_id: status2['id'] + 1)
      expect(chunk).to eq [status2, status1]
      expect(request_stub).to have_been_requested.times(1)
    end

    it 'returns statuses with ids less than or equal to from_id' do
      chunk = instance.public_timeline_chunk(from_id: status2['id'])
      expect(chunk).to eq [status2, status1]
      expect(request_stub).to have_been_requested.times(1)
    end

    it 'returns statuses from the beginning if from_id is greater than the first id' do
      chunk = instance.public_timeline_chunk(from_id: status3['id'] + 1)
      expect(chunk).to eq [status3, status2, status1]
      expect(request_stub).to have_been_requested.times(1)
    end

    it 'returns statuses from the beginning if from_id is equal to the first id' do
      chunk = instance.public_timeline_chunk(from_id: status3['id'])
      expect(chunk).to eq [status3, status2, status1]
      expect(request_stub).to have_been_requested.times(1)
    end

    it 'returns nothing if from_id is too small' do
      chunk = instance.public_timeline_chunk(from_id: status1['id'] - 1)
      expect(chunk).to be_empty
      expect(request_stub).to have_been_requested.times(1)
    end

    it 'repeats HTTP requests if from_id is not specified' do
      chunk = instance.public_timeline_chunk
      chunk = instance.public_timeline_chunk

      expect(request_stub).to have_been_requested.times(2)
    end

    it 'does not repeat HTTP requests if from_id is specified and result is cached' do
      chunk = instance.public_timeline_chunk(from_id: status2['id'])
      chunk = instance.public_timeline_chunk(from_id: status2['id'])

      expect(request_stub).to have_been_requested.times(1)
    end
  end
end
