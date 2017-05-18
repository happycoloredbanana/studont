require 'spec_helper'

RSpec.describe Studont::Timeline do
  let(:instance) { double('Instance') }

    def filter_statuses_from_id(statuses: statuses, from_id: nil)
      statuses.select { |status| from_id.nil? || status['id'] <= from_id }
    end

  context 'when neither newest nor oldest are specified' do
    let(:status1) { { 'id' => 1 } }
    let(:status2) { { 'id' => 2 } }
    let(:status3) { { 'id' => 3 } }

    it 'returns nothing when public timeline contains nothing' do
      allow(instance).to receive(:public_timeline_chunk).once.and_return([])
      timeline = Studont::Timeline.new(instance: instance)
      expect(timeline.to_a()).to be_empty
    end

    it 'returns all the statuses retrieved' do
      allow(instance).to receive(:public_timeline_chunk).twice.and_return([status3, status2, status1], [])
      timeline = Studont::Timeline.new(instance: instance)
      expect(timeline.to_a()).to eq([status3, status2, status1])
    end

    it 'returns all the statuses retrieved in chunks' do
      allow(instance).to receive(:public_timeline_chunk).exactly(3).times.and_return([status3, status2], [status1], [])
      timeline = Studont::Timeline.new(instance: instance)
      expect(timeline.to_a()).to eq([status3, status2, status1])
    end
  end

  context 'when only newest is specified' do

    context 'when using an id' do
      let(:status1) { { 'id' => 3 } }
      let(:status2) { { 'id' => 4 } }
      let(:status3) { { 'id' => 6 } }

      before(:each) do
        allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
        end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, newest: 1)
        expect(timeline.to_a()).to be_empty
      end

      it 'returns all the statuses when the specified id is newer than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'] + 1)
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses when the specified id is actually the newest id on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'])
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'starts from the specified id when status with this id is available' do
        timeline = Studont::Timeline.new(instance: instance, newest: status2['id'])
        expect(timeline.first(2)).to eq([status2, status1])
      end

      it 'starts from the next closest id when the status with the specified id is missing' do
        timeline = Studont::Timeline.new(instance: instance, newest: status2['id'] + 1)
        expect(timeline.first(2)).to eq([status2, status1])
      end

      it 'returns nothing when statuses with specified id and older are missing' do
        timeline = Studont::Timeline.new(instance: instance, newest: status1['id'] - 1)
        expect(timeline.to_a).to be_empty
      end
    end

    context 'when using a DateTime' do

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse('2017-05-15T20:07:00.000Z'))
        expect(timeline.to_a()).to be_empty
      end

      shared_examples 'timeline' do |status1, status2, status3|
        it 'returns all the statuses when the specified date is newer than everything on the timeline' do
          timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']) + 1/86400r)
          expect(timeline.to_a()).to eq([status3, status2, status1])
        end

        it 'returns all the statuses when the specified date is equal to the date of thew newest post' do
          timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']))
          expect(timeline.to_a()).to eq([status3, status2, status1])
        end

        it 'returns all the statuses with date older than the specified date, if there\'s no status with exact date' do
          timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status2['created_at']) + 1/86400r)
          expect(timeline.to_a()).to eq([status2, status1])
        end

        it 'returns all the statuses with date older or equal to the specified date' do
          timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status2['created_at']))
          expect(timeline.to_a()).to eq([status2, status1])
        end

        it 'returns nothing when all the statuses on the timeline are too new' do
          timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status1['created_at']) - 1/86400r)
          expect(timeline.to_a()).to be_empty
        end
      end

      context 'when timeline contains status with id==1' do
        status1  = { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' }
        status2  = { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' }
        status3  = { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' }

        before(:each) do
          allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
          end
        end

        include_examples 'timeline', status1, status2, status3
      end

      context 'when timeline does not contain status with id==1' do
        status1 = { 'id' => 4, 'created_at' => '2017-05-15T20:07:00.000Z' }
        status2 = { 'id' => 5, 'created_at' => '2017-05-15T20:08:00.000Z' }
        status3 = { 'id' => 6, 'created_at' => '2017-05-15T20:09:00.000Z' }

        before(:each) do
          allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
          end
        end

        include_examples 'timeline', status1, status2, status3
      end
    end

    context 'when using a string' do
      let(:status1) { { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } }
      let(:status2) { { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } }
      let(:status3) { { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } }

      before(:each) do
        allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
        end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, newest: '2017-05-15T20:07:00.000Z')
        expect(timeline.to_a()).to be_empty
      end

      it 'returns all the statuses when the specified date is newer than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: (DateTime.parse(status3['created_at']) + 1/86400r).to_s)
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses when the specified date is equal to the date of thew newest post' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['created_at'])
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses with date older than the specified date, if there\'s no status with exact date' do
        timeline = Studont::Timeline.new(instance: instance, newest: (DateTime.parse(status2['created_at']) + 1/86400r).to_s)
        expect(timeline.to_a()).to eq([status2, status1])
      end

      it 'returns all the statuses with date older or equal to the specified date' do
        timeline = Studont::Timeline.new(instance: instance, newest: status2['created_at'])
        expect(timeline.to_a()).to eq([status2, status1])
      end

      it 'returns nothing when all the statuses on the timeline are too new' do
        timeline = Studont::Timeline.new(instance: instance, newest: (DateTime.parse(status1['created_at']) - 1/86400r).to_s)
        expect(timeline.to_a()).to be_empty
      end
    end
  end

  context 'when only oldest is specified' do

    context 'when using an id' do
      let(:status1) { { 'id' => 4 } }
      let(:status2) { { 'id' => 6 } }
      let(:status3) { { 'id' => 7 } }

      before(:each) do
        allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
        end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, oldest: 1)
        expect(timeline.to_a()).to be_empty
      end

      it 'returns all the statuses when the specified id is older than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, oldest: status1['id'] - 1)
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses when the specified id is actually the oldest id on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, oldest: status1['id'])
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'ends with the specified id when status with this id is available' do
        timeline = Studont::Timeline.new(instance: instance, oldest: status2['id'])
        expect(timeline.first(2)).to eq([status3, status2])
      end

      it 'ends with the next closest id when the status with the specified id is missing' do
        timeline = Studont::Timeline.new(instance: instance, oldest: status2['id'] - 1)
        expect(timeline.first(2)).to eq([status3, status2])
      end

      it 'returns nothing when statuses with specified id and newer are missing' do
        timeline = Studont::Timeline.new(instance: instance, oldest: status3['id'] + 1)
        expect(timeline.to_a).to be_empty
      end
    end

    context 'when using a DateTime' do
      let(:status1) { { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } }
      let(:status2) { { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } }
      let(:status3) { { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } }

      before(:each) do
        allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
        end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, oldest: DateTime.parse('2017-05-15T20:07:00.000Z'))
        expect(timeline.to_a()).to be_empty
      end

      it 'returns all the statuses when the specified date is older than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, oldest: DateTime.parse(status1['created_at']) - 1/86400r)
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses when the specified date is equal to the date of thew oldest post' do
        timeline = Studont::Timeline.new(instance: instance, oldest: DateTime.parse(status1['created_at']))
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses with date newer than the specified date, if there\'s no status with exact date' do
        timeline = Studont::Timeline.new(instance: instance, oldest: DateTime.parse(status2['created_at']) - 1/86400r)
        expect(timeline.to_a()).to eq([status3, status2])
      end

      it 'returns all the statuses with date newer or equal to the specified date' do
        timeline = Studont::Timeline.new(instance: instance, oldest: DateTime.parse(status2['created_at']))
        expect(timeline.to_a()).to eq([status3, status2])
      end

      it 'returns nothing when all the statuses on the timeline are too old' do
        timeline = Studont::Timeline.new(instance: instance, oldest: DateTime.parse(status3['created_at']) + 1/86400r)
        expect(timeline.to_a()).to be_empty
      end
    end

    context 'when using a string' do
      let(:status1) { { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } }
      let(:status2) { { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } }
      let(:status3) { { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } }

      before(:each) do
        allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
        end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, oldest: '2017-05-15T20:07:00.000Z')
        expect(timeline.to_a()).to be_empty
      end

      it 'returns all the statuses when the specified date is older than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, oldest: (DateTime.parse(status1['created_at']) - 1/86400r).to_s)
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses when the specified date is equal to the date of thew oldest post' do
        timeline = Studont::Timeline.new(instance: instance, oldest: status1['created_at'])
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses with date newer than the specified date, if there\'s no status with exact date' do
        timeline = Studont::Timeline.new(instance: instance, oldest: (DateTime.parse(status2['created_at']) - 1/86400r).to_s)
        expect(timeline.to_a()).to eq([status3, status2])
      end

      it 'returns all the statuses with date newer or equal to the specified date' do
        timeline = Studont::Timeline.new(instance: instance, oldest: status2['created_at'])
        expect(timeline.to_a()).to eq([status3, status2])
      end

      it 'returns nothing when all the statuses on the timeline are too old' do
        timeline = Studont::Timeline.new(instance: instance, oldest: (DateTime.parse(status3['created_at']) + 1/86400r).to_s)
        expect(timeline.to_a()).to be_empty
      end
    end
  end

  context 'when both newest and oldest are specified' do

    context 'when using ids for both' do
      let(:status1) { { 'id' => 3 } }
      let(:status2) { { 'id' => 4 } }
      let(:status3) { { 'id' => 6 } }

      before(:each) do
        allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
        end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, newest: 3, oldest: 1)
        expect(timeline.to_a()).to be_empty
      end

      it 'returns nothing when both newest and oldest are newer than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'] + 2, oldest: status3['id'] + 1)
        expect(timeline.to_a()).to be_empty
      end

      it 'returns nothing when both newest and oldest are older than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: status1['id'] - 1, oldest: status1['id'] - 2)
        expect(timeline.to_a()).to be_empty
      end

      it 'returns all the statuses when the timeline is inside [newest, oldest]' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'] + 1, oldest: status1['id'] - 1)
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses when the timeline is equal to [newest, oldest]' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'], oldest: status1['id'])
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns relevant statuses when the overlap is like: newest, start of timeline, oldest, end of timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'] + 1, oldest: status2['id'])
        expect(timeline.to_a()).to eq([status3, status2])
      end

      it 'returns relevant statuses when the overlap is like: start of timeline, newest, end of timeline, oldest' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'] - 1, oldest: status1['id'] - 1)
        expect(timeline.to_a()).to eq([status2, status1])
      end

      it 'returns a single status when newest == oldest and the status exists' do
        timeline = Studont::Timeline.new(instance: instance, newest: status2['id'], oldest: status2['id'])
        expect(timeline.to_a()).to eq([status2])
      end

      it 'returns nothing when newest == oldest and the status does not exist' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['id'] - 1, oldest: status3['id'] - 1)
        expect(timeline.to_a()).to be_empty
      end
    end

    context 'when using date for both' do
      let(:status1) { { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' } }
      let(:status2) { { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' } }
      let(:status3) { { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' } }

      before(:each) do
        allow(instance).to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1], from_id: from_id)
        end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance: instance, newest: '2017-05-15T20:09:00.000Z',
          oldest: '2017-05-15T20:07:00.000Z')
        expect(timeline.to_a()).to be_empty
      end

      it 'returns nothing when both newest and oldest are newer than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']) + 2/86400r,
          oldest: DateTime.parse(status3['created_at']) + 1/86400r)
        expect(timeline.to_a()).to be_empty
      end

      it 'returns nothing when both newest and oldest are older than everything on the timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status1['created_at']) - 1/86400r,
          oldest: DateTime.parse(status1['created_at']) - 2/86400r)
        expect(timeline.to_a()).to be_empty
      end

      it 'returns all the statuses when the timeline is inside [newest, oldest]' do
        timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']) + 1/86400r,
          oldest: DateTime.parse(status1['created_at']) - 1/86400r)
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns all the statuses when the timeline is equal to [newest, oldest]' do
        timeline = Studont::Timeline.new(instance: instance, newest: status3['created_at'],
          oldest: status1['created_at'])
        expect(timeline.to_a()).to eq([status3, status2, status1])
      end

      it 'returns relevant statuses when the overlap is like: newest, start of timeline, oldest, end of timeline' do
        timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']) + 1/86400r,
          oldest: DateTime.parse(status2['created_at']) - 1/86400r)
        expect(timeline.to_a()).to eq([status3, status2])
      end

      it 'returns relevant statuses when the overlap is like: start of timeline, newest, end of timeline, oldest' do
        timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']) - 1/86400r,
          oldest: DateTime.parse(status1['created_at']) - 1/86400r)
        expect(timeline.to_a()).to eq([status2, status1])
      end

      it 'returns a single status when newest == oldest and the status exists' do
        timeline = Studont::Timeline.new(instance: instance, newest: status2['created_at'],
          oldest: status2['created_at'])
        expect(timeline.to_a()).to eq([status2])
      end

      it 'returns nothing when newest == oldest and the status does not exist' do
        timeline = Studont::Timeline.new(instance: instance, newest: DateTime.parse(status3['created_at']) - 1/86400r,
          oldest: DateTime.parse(status3['created_at']) - 1/86400r)
        expect(timeline.to_a()).to be_empty
      end
    end
  end
end
