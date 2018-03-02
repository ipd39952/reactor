require 'spec_helper'

describe Reactor::Cm::Job do
  describe '.create' do
    let(:job_name) { 'my_test_job' }
    let(:attributes) { Hash.new }

    before { described_class.create(job_name, attributes) }
    after  { described_class.delete!(job_name) }

    it 'creates a job with given name' do
      expect(described_class.exists?(job_name)).to be_truthy
    end

    it 'is readable directly from the database' do
      expect(RailsConnector::Job.exists?(job_name: job_name)).to be_truthy
    end

    it 'does not raise exception when getting created job' do
      expect { described_class.get(job_name) }.not_to raise_exception
    end

    context 'with attributes' do
      let(:attributes) do
        {
          :title => 'test title',
          :is_active => '0',
          :comment => 'super interesting job',
          :exec_login => 'not_root',
          :script => 'obj wherePath / get description',
          :schedule => [
            {:years => ['2013'], :minutes => ['11']},
            {:years => ['2012', '2014'], :minutes => ['55']}
        ]
        }
      end

      subject { described_class.get(job_name) }

      [:title, :comment, :exec_login, :script, :is_active].each do |attribute|
        it "sets #{attribute}" do
          expect(subject.send(attribute)).to eq(attributes[attribute])
        end
      end

      it "stores title in the database" do
        job = RailsConnector::Job.find_by_job_name(job_name)
        expect(job.title).to eq(attributes[:title])
      end

      it "stores comment in the database" do
        job = RailsConnector::Job.find_by_job_name(job_name)
        expect(job.job_comment).to eq(attributes[:comment])

      end

      it "stores is_active in the database" do
        job = RailsConnector::Job.find_by_job_name(job_name)
        expect(job.is_active).to eq(attributes[:is_active].to_i)
      end

      it "sets schedule" do
        schedule = subject.schedule
        expect(schedule.entries.size).to eq(2)

        first = schedule.first
        second = schedule.last

        expect(first[:years]).to eq(['2013'])
        expect(first[:minutes]).to eq(['11'])

        expect(second[:years]).to eq(['2012', '2014'])
        expect(second[:minutes]).to eq(['55'])
      end
    end
  end
end
