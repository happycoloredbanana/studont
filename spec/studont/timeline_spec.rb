require 'spec_helper'

RSpec.describe Studont::Timeline do
  it 'returns nothing when public timeline contains nothing' do
    instance = double('Instance')
    allow(instance).to receive(:public_timeline_chunk).once.and_return([])
    timeline = Studont::Timeline.new(instance: instance)
    expect(timeline.to_a()).to be_empty
  end

  it 'returns all the statuses retrieved' do
    instance = double('Instance')
    status1 = { 'id' => 1 } 
    status2 = { 'id' => 2 } 
    status3 = { 'id' => 3 } 
    allow(instance).to receive(:public_timeline_chunk).twice.and_return([status3, status2, status1], [])
    timeline = Studont::Timeline.new(instance: instance)
    expect(timeline.to_a()).to eq([status3, status2, status1])
  end

  it 'returns all the statuses retrieved in chunks' do
    instance = double('Instance')
    status1 = { 'id' => 1 } 
    status2 = { 'id' => 2 } 
    status3 = { 'id' => 3 } 
    allow(instance).to receive(:public_timeline_chunk).exactly(3).times.and_return([status3, status2], [status1], [])
    timeline = Studont::Timeline.new(instance: instance)
    expect(timeline.to_a()).to eq([status3, status2, status1])
  end

  it 'returns nothing when public timeline contains nothing and newest id is specified' do
    instance = double('Instance')
    allow(instance).to receive(:public_timeline_chunk).once.and_return([])
    timeline = Studont::Timeline.new(instance: instance, newest: 1)
    expect(timeline.to_a()).to be_empty
  end

  it 'returns all the statuses when the specified newest id is newer than everything on the timeline' do
    instance = double('Instance')
    status1 = { 'id' => 1 } 
    status2 = { 'id' => 2 } 
    status3 = { 'id' => 3 } 
    allow(instance).to receive(:public_timeline_chunk).twice.and_return([status3, status2, status1], [])
    timeline = Studont::Timeline.new(instance: instance, newest: status3['id'] + 1)
    expect(timeline.to_a()).to eq([status3, status2, status1])
  end

  it 'returns all the statuses when the specified newest id is actually the newest id on the timeline' do
    instance = double('Instance')
    status1 = { 'id' => 1 } 
    status2 = { 'id' => 2 } 
    status3 = { 'id' => 3 } 
    allow(instance).to receive(:public_timeline_chunk).twice.and_return([status3, status2, status1], [])
    timeline = Studont::Timeline.new(instance: instance, newest: status3['id'])
    expect(timeline.to_a()).to eq([status3, status2, status1])
  end

  it 'starts from the specified newest id when status with this id is available' do
    instance = double('Instance')
    status1 = { 'id' => 1 } 
    status2 = { 'id' => 2 } 
    status3 = { 'id' => 3 } 
    allow(instance).to receive(:public_timeline_chunk).once.and_return([status3, status2, status1])
    timeline = Studont::Timeline.new(instance: instance, newest: status2['id'])
    expect(timeline.first(2)).to eq([status2, status1])
  end

  it 'starts from the next closest id when the status with newest id is missing' do
    instance = double('Instance')
    status1 = { 'id' => 1 } 
    status2 = { 'id' => 2 } 
    status3 = { 'id' => 4 } 
    allow(instance).to receive(:public_timeline_chunk).once.and_return([status3, status2, status1])
    timeline = Studont::Timeline.new(instance: instance, newest: status2['id'] + 1)
    expect(timeline.first(2)).to eq([status2, status1])
  end

  it 'returns nothing when statuses with specified newest id and older are missing' do
    instance = double('Instance')
    status1 = { 'id' => 3 } 
    status2 = { 'id' => 4 } 
    status3 = { 'id' => 5 } 
    allow(instance).to receive(:public_timeline_chunk).once.and_return([status3, status2, status1])
    timeline = Studont::Timeline.new(instance: instance, newest: status1['id'] - 1)
    expect(timeline.to_a).to be_empty
  end

  it 'returns nothing when public timeline contains nothing and newest date is specified' do
    instance = double('Instance')
    allow(instance).to receive(:public_timeline_chunk).once.and_return([])
    timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse('2017-05-15T20:07:00.000Z'))
    expect(timeline.to_a()).to be_empty
  end

  it 'returns all the statuses when the specified newest date is newer than everything on the timeline' do
    instance = double('Instance')
    status1 = { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } 
    status2 = { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } 
    status3 = { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } 
    allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
      result = [status3, status2, status1].select { |status| from_id.nil? || status['id'] <= from_id }
      result
    end
    timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']) + 1/86400r)
    expect(timeline.to_a()).to eq([status3, status2, status1])
  end

  it 'returns all the statuses when the specified newest date is equal to the date of thew newest post' do
    instance = double('Instance')
    status1 = { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } 
    status2 = { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } 
    status3 = { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } 
    allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
      result = [status3, status2, status1].select { |status| from_id.nil? || status['id'] <= from_id }
      result
    end
    timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']))
    expect(timeline.to_a()).to eq([status3, status2, status1])
  end

  it 'returns all the statuses with date older than the specified newest date, if there\'s no status with exact date' do
    instance = double('Instance')
    status1 = { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } 
    status2 = { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } 
    status3 = { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } 
    allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
      result = [status3, status2, status1].select { |status| from_id.nil? || status['id'] <= from_id }
      result
    end
    timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status2['created_at']) + 1/86400r)
    expect(timeline.to_a()).to eq([status2, status1])
  end

  it 'returns all the statuses with date older or equal to the specified newest date' do
    instance = double('Instance')
    status1 = { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } 
    status2 = { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } 
    status3 = { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } 
    allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
      result = [status3, status2, status1].select { |status| from_id.nil? || status['id'] <= from_id }
      result
    end
    timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status2['created_at']))
    expect(timeline.to_a()).to eq([status2, status1])
  end

  it 'returns nothing when all the statuses on the timeline are too new' do
    instance = double('Instance')
    status1 = { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } 
    status2 = { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } 
    status3 = { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } 
    allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
      result = [status3, status2, status1].select { |status| from_id.nil? || status['id'] <= from_id }
      result
    end
    timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status1['created_at']) - 1/86400r)
    expect(timeline.to_a()).to be_empty
  end
end
