# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Studont::Timeline do
  let(:instance) { double('Instance') }

  def filter_statuses_from_id(statuses:, from_id: nil)
    statuses.select { |status| from_id.nil? || status['id'] <= from_id }
  end

  def date_from_status(status, delta_secs = 0)
    DateTime.parse(status['created_at']) + delta_secs / 86400r
  end

  context 'when neither newest nor oldest are used' do
    let(:status1) { { 'id' => 1 } }
    let(:status2) { { 'id' => 2 } }
    let(:status3) { { 'id' => 3 } }

    context 'when public timeline is empty' do
      it 'returns nothing' do
        allow(instance).to receive(:public_timeline_chunk).once.and_return([])
        timeline = Studont::Timeline.new(instance)
        expect(timeline.to_a).to be_empty
      end
    end

    context 'when all statuses retreived at once' do
      it 'returns everything' do
        allow(instance).to receive(:public_timeline_chunk).twice
          .and_return([status3, status2, status1], [])
        timeline = Studont::Timeline.new(instance)
        expect(timeline.to_a).to eq([status3, status2, status1])
      end
    end

    context 'when statuses retreived in chunks' do
      it 'returns everyting' do
        allow(instance).to receive(:public_timeline_chunk).exactly(3).times
          .and_return([status3, status2], [status1], [])
        timeline = Studont::Timeline.new(instance)
        expect(timeline.to_a).to eq([status3, status2, status1])
      end
    end
  end

  context 'when only newest is used' do
    context 'when using an id' do
      let(:status1) { { 'id' => 3 } }
      let(:status2) { { 'id' => 4 } }
      let(:status3) { { 'id' => 6 } }

      before(:each) do
        allow(instance)
          .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1],
                                    from_id: from_id)
          end
      end

      context 'when public timeline is empty' do
        it 'returns nothing' do
          allow(instance).to receive(:public_timeline_chunk).once.and_return([])
          timeline = Studont::Timeline.new(
            instance,
            newest: 1
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the id is newer than everything on the timeline' do
        it 'returns everything ' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id'] + 1
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the id is the newest id on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id']
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when status with the id exists' do
        it 'starts from the id' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status2['id']
          )
          expect(timeline.to_a).to eq([status2, status1])
        end
      end

      context 'when status with the id does not exist' do
        it 'starts from the next closest id' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status2['id'] + 1
          )
          expect(timeline.to_a).to eq([status2, status1])
        end
      end

      context 'when status with the id and older do not exist' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status1['id'] - 1
          )
          expect(timeline.to_a).to be_empty
        end
      end
    end

    context 'when using a DateTime' do
      context 'when public timeline is empty' do
        it 'returns nothing' do
          allow(instance)
            .to receive(:public_timeline_chunk).once.and_return([])
          some_date = DateTime.parse('2017-05-15T20:07:00.000Z')
          timeline = Studont::Timeline.new(
            instance,
            newest: some_date
          )
          expect(timeline.to_a).to be_empty
        end
      end

      shared_examples 'timeline' do |status1, status2, status3|
        context 'when the date is newer than newest on the timeline' do
          it 'returns everything' do
            timeline = Studont::Timeline.new(
              instance,
              newest: date_from_status(status3, +1)
            )
            expect(timeline.to_a).to eq([status3, status2, status1])
          end
        end

        context 'when the date is equal to the date of the newest' do
          it 'returns everything' do
            timeline = Studont::Timeline.new(
              instance,
              newest: date_from_status(status3)
            )
            expect(timeline.to_a).to eq([status3, status2, status1])
          end
        end

        context 'when status with the exact date does not exist' do
          it 'returns statuses with older dates' do
            timeline = Studont::Timeline.new(
              instance,
              newest: date_from_status(status2, +1)
            )
            expect(timeline.to_a).to eq([status2, status1])
          end
        end

        context 'when status with the exact date exists' do
          it 'returns statuses with dates older or equal' do
            timeline = Studont::Timeline.new(
              instance,
              newest: date_from_status(status2)
            )
            expect(timeline.to_a).to eq([status2, status1])
          end
        end

        context 'when statuses on the timeline are too new' do
          it 'returns nothing' do
            timeline = Studont::Timeline.new(
              instance,
              newest: date_from_status(status1, -1)
            )
            expect(timeline.to_a).to be_empty
          end
        end
      end

      context 'when timeline contains status with id==1' do
        status1  = { 'id' => 1, 'created_at' => '2017-05-15T20:07:00.000Z' }
        status2  = { 'id' => 2, 'created_at' => '2017-05-15T20:08:00.000Z' }
        status3  = { 'id' => 3, 'created_at' => '2017-05-15T20:09:00.000Z' }

        before(:each) do
          allow(instance)
            .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
              filter_statuses_from_id(statuses: [status3, status2, status1],
                                      from_id: from_id)
            end
        end

        include_examples 'timeline', status1, status2, status3
      end

      context 'when timeline does not contain status with id==1' do
        status1 = { 'id' => 4, 'created_at' => '2017-05-15T20:07:00.000Z' }
        status2 = { 'id' => 5, 'created_at' => '2017-05-15T20:08:00.000Z' }
        status3 = { 'id' => 6, 'created_at' => '2017-05-15T20:09:00.000Z' }

        before(:each) do
          allow(instance)
            .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
              filter_statuses_from_id(statuses: [status3, status2, status1],
                                      from_id: from_id)
            end
        end

        include_examples 'timeline', status1, status2, status3
      end
    end

    context 'when using a string' do
      let(:status1) do
        { 'id' => 1,
          'created_at' => '2017-05-15T20:07:00.000Z' }
      end
      let(:status2) do
        { 'id' => 2,
          'created_at' => '2017-05-15T20:08:00.000Z' }
      end
      let(:status3) do
        { 'id' => 3,
          'created_at' => '2017-05-15T20:09:00.000Z' }
      end

      before(:each) do
        allow(instance)
          .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1],
                                    from_id: from_id)
          end
      end

      context 'when public timeline is empty' do
        it 'returns nothing' do
          allow(instance)
            .to receive(:public_timeline_chunk).once.and_return([])
          timeline = Studont::Timeline.new(
            instance,
            newest: '2017-05-15T20:07:00.000Z'
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the date is newer than everything on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status3, +1).to_s
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the date is equal to the the newest on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['created_at']
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when exact date does not exist' do
        it 'returns statuses older than the date' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status2, +1).to_s
          )
          expect(timeline.to_a).to eq([status2, status1])
        end
      end

      context 'when exact date exist' do
        it 'returns statuses with date older or equal' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status2['created_at']
          )
          expect(timeline.to_a).to eq([status2, status1])
        end
      end

      context 'when statuses on the timeline are too new' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status1, -1).to_s
          )
          expect(timeline.to_a).to be_empty
        end
      end
    end
  end

  context 'when only oldest is specified' do
    context 'when using an id' do
      let(:status1) { { 'id' => 4 } }
      let(:status2) { { 'id' => 6 } }
      let(:status3) { { 'id' => 7 } }

      before(:each) do
        allow(instance)
          .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1],
                                    from_id: from_id)
          end
      end

      context 'when public timeline is empty' do
        it 'returns nothing' do
          allow(instance).to receive(:public_timeline_chunk).once.and_return([])
          timeline = Studont::Timeline.new(instance, oldest: 1)
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the id is older than everything on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: status1['id'] - 1
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the id is the oldest on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: status1['id']
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the id exists on the timeline' do
        it 'ends with the id' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: status2['id']
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'when the id does not exist on the timeline' do
        it 'ends with the next closest id' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: status2['id'] - 1
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'when the id is newer than everything on the timeline' do
        it 'returns nothing when' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: status3['id'] + 1
          )
          expect(timeline.to_a).to be_empty
        end
      end
    end

    context 'when using a DateTime' do
      let(:status1) do
        { 'id' => 1,
          'created_at' => '2017-05-15T20:07:00.000Z' }
      end
      let(:status2) do
        { 'id' => 2,
          'created_at' => '2017-05-15T20:08:00.000Z' }
      end
      let(:status3) do
        { 'id' => 3,
          'created_at' => '2017-05-15T20:09:00.000Z' }
      end

      before(:each) do
        allow(instance)
          .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1],
                                    from_id: from_id)
          end
      end

      context 'when public timeline is empty' do
        it 'returns nothing' do
          allow(instance)
            .to receive(:public_timeline_chunk).once.and_return([])
          some_date = DateTime.parse('2017-05-15T20:07:00.000Z')
          timeline = Studont::Timeline.new(
            instance,
            oldest: some_date
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the date is older than everything on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: date_from_status(status1, -1)
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the date is the oldest on the timeline' do
        it 'returns everything' do
          status1_created_at = DateTime.parse(status1['created_at'])
          timeline = Studont::Timeline.new(
            instance,
            oldest: status1_created_at
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when exact date does not exist' do
        it 'returns statuses newer than the date' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: date_from_status(status2, -1)
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'when exact date exist' do
        it 'returns statuses newer or equal than the date' do
          status2_created_at = DateTime.parse(status2['created_at'])
          timeline = Studont::Timeline.new(
            instance,
            oldest: status2_created_at
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'when everything on the timeline is too old' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: date_from_status(status3, +1)
          )
          expect(timeline.to_a).to be_empty
        end
      end
    end

    context 'when using a string' do
      let(:status1) do
        { 'id' => 1,
          'created_at' => '2017-05-15T20:07:00.000Z' }
      end
      let(:status2) do
        { 'id' => 2,
          'created_at' => '2017-05-15T20:08:00.000Z' }
      end
      let(:status3) do
        { 'id' => 3,
          'created_at' => '2017-05-15T20:09:00.000Z' }
      end

      before(:each) do
        allow(instance)
          .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1],
                                    from_id: from_id)
          end
      end

      it 'returns nothing when public timeline contains nothing' do
        allow(instance)
          .to receive(:public_timeline_chunk).once.and_return([])
        some_date = '2017-05-15T20:07:00.000Z'
        timeline = Studont::Timeline.new(
          instance,
          oldest: some_date
        )
        expect(timeline.to_a).to be_empty
      end

      context 'the date is older than everything on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: date_from_status(status1, -1).to_s
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the date is the oldest on the timeline' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: status1['created_at']
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'the exact date does not exist on the timeline' do
        it 'returns statuses with newer dates' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: date_from_status(status2, -1).to_s
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'the exact date exists on the timeline' do
        it 'returns statuses with newer or equal dates' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: status2['created_at']
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'when everything on the timeline is older than the date' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            oldest: date_from_status(status3, +1).to_s
          )
          expect(timeline.to_a).to be_empty
        end
      end
    end
  end

  context 'when both newest and oldest are specified' do
    context 'when using ids for both' do
      let(:status1) { { 'id' => 3 } }
      let(:status2) { { 'id' => 4 } }
      let(:status3) { { 'id' => 6 } }

      before(:each) do
        allow(instance)
          .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
            filter_statuses_from_id(statuses: [status3, status2, status1],
                                    from_id: from_id)
          end
      end

      context 'when public timeline is empty' do
        it 'returns nothing' do
          allow(instance)
            .to receive(:public_timeline_chunk).once.and_return([])
          timeline = Studont::Timeline.new(
            instance,
            newest: 3,
            oldest: 1
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the ids are newer than everything on the timeline' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id'] + 2,
            oldest: status3['id'] + 1
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the ids are older than everything on the timeline' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status1['id'] - 1,
            oldest: status1['id'] - 2
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the timeline is inside [newest, oldest]' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id'] + 1,
            oldest: status1['id'] - 1
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the timeline is equal to [newest, oldest]' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id'],
            oldest: status1['id']
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when overlap: newest, timeline start, oldest, timeline end' do
        it 'returns the intersection' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id'] + 1,
            oldest: status2['id']
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'when overlap: timeline start, newest, timeline end, oldest' do
        it 'returns the intersection' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id'] - 1,
            oldest: status1['id'] - 1
          )
          expect(timeline.to_a).to eq([status2, status1])
        end
      end

      context 'when newest == oldest and the status exists' do
        it 'returns a single status ' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status2['id'],
            oldest: status2['id']
          )
          expect(timeline.to_a).to eq([status2])
        end
      end

      context 'when newest == oldest and the status does not exist' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['id'] - 1,
            oldest: status3['id'] - 1
          )
          expect(timeline.to_a).to be_empty
        end
      end
    end

    context 'when using date for both' do
      let(:status1) do
        { 'id' => 1,
          'created_at' => '2017-05-15T20:07:00.000Z' }
      end
      let(:status2) do
        { 'id' => 2,
          'created_at' => '2017-05-15T20:08:00.000Z' }
      end
      let(:status3) do
        { 'id' => 3,
          'created_at' => '2017-05-15T20:09:00.000Z' }
      end

      before(:each) do
        allow(instance)
          .to receive(:public_timeline_chunk) do |local: true, from_id: nil|
          filter_statuses_from_id(statuses: [status3, status2, status1],
                                  from_id: from_id)
        end
      end

      context 'when public timeline is empty' do
        it 'returns nothing' do
          allow(instance)
            .to receive(:public_timeline_chunk).once.and_return([])
          some_date = '2017-05-15T20:09:00.000Z'
          another_date = '2017-05-15T20:07:00.000Z'
          timeline = Studont::Timeline.new(
            instance,
            newest: some_date,
            oldest: another_date
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the dates are newer than everything on the timeline' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status3, +2),
            oldest: date_from_status(status3, +1)
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the dates are older than everything on the timeline' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status1, -1),
            oldest: date_from_status(status1, -2)
          )
          expect(timeline.to_a).to be_empty
        end
      end

      context 'when the timeline is inside [newest, oldest]' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status3, +1),
            oldest: date_from_status(status1, -1)
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when the timeline is equal to [newest, oldest]' do
        it 'returns everything' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status3['created_at'],
            oldest: status1['created_at']
          )
          expect(timeline.to_a).to eq([status3, status2, status1])
        end
      end

      context 'when overlap: newest, timeline start, oldest, timeline end' do
        it 'returns the intersection' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status3, +1),
            oldest: date_from_status(status2, -1)
          )
          expect(timeline.to_a).to eq([status3, status2])
        end
      end

      context 'when overlap: timeline start, newest, timeline end, oldest' do
        it 'returns the intersection' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status3, -1),
            oldest: date_from_status(status1, -1)
          )
          expect(timeline.to_a).to eq([status2, status1])
        end
      end

      context 'when newest == oldest and the status exists' do
        it 'returns a single status' do
          timeline = Studont::Timeline.new(
            instance,
            newest: status2['created_at'],
            oldest: status2['created_at']
          )
          expect(timeline.to_a).to eq([status2])
        end
      end

      context 'when newest == oldest and the status does not exist' do
        it 'returns nothing' do
          timeline = Studont::Timeline.new(
            instance,
            newest: date_from_status(status3, -1),
            oldest: date_from_status(status3, -1)
          )
          expect(timeline.to_a).to be_empty
        end
      end
    end
  end
end
