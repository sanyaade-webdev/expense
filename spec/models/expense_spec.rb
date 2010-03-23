require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Expense do
  before do
    Time.zone = 'Central Time (US & Canada)'
  end

  describe 'class' do
    describe 'when calculating the average for a given unit' do
      before do
        Expense.stub!(:find_averages_for).and_return([5, 10])
        Expense.stub!(:determine_duration_since_first_entry_in).and_return(2)
      end

      it 'should return the average' do
        Expense.calculate_average_for(:day).should == 7.5
      end
    end

    describe 'when determing if the current average is above the overall average' do
      describe 'with records' do
        before do
          Expense.stub!(:first).and_return(true)
          Expense.stub!(:find_averages_for).and_return([4, 8])
          Expense.stub!(:calculate_average_for).and_return(2)
        end

        it 'should find the averages for the provided unit' do
          Expense.should_receive(:find_averages_for).with(:day)
          Expense.is_above_average_for?(:day)
        end

        it 'should calculate the averages for the provided unit' do
          Expense.should_receive(:calculate_average_for).with(:day)
          Expense.is_above_average_for?(:day)
        end

        describe 'when the current average is greater than the overall' do
          it 'should return true' do
            Expense.is_above_average_for?(:week).should == true
          end
        end

        describe 'when the current average is less than the overall' do
          before do
            Expense.stub!(:find_averages_for).and_return([2, 4])
            Expense.stub!(:calculate_average_for).and_return(4)
          end

          it 'should return false' do
            Expense.is_above_average_for?(:week).should == false
          end
        end
      end

      describe 'without records' do
        before do
          Expense.stub!(:first)
        end

        it 'should return false' do
          Expense.is_above_average_for?(:month).should == false
        end
      end
    end

    describe 'when finding recent expenses grouped by relative date' do
      fixtures :expenses, :users

      it 'should return an array of groups' do
        users(:default).expenses.find_recent_grouped_by_relative_date.to_a.should == [['Today', [expenses(:default)]]]
      end

      it 'should support a custom limit' do
        users(:default).expenses.find_recent_grouped_by_relative_date(0).to_a.should == []
      end
    end

    describe 'when finding averages by range' do
      fixtures :expenses, :users

      describe 'of days' do
        it 'should return averages for each day' do
          users(:bob).expenses.find_averages_for(:day).should == [7.50, 40.00, 60.00, 25.00]
        end
      end

      describe 'of weeks' do
        it 'should return averages for each week' do
          users(:bob).expenses.find_averages_for(:week).should == [7.50, 50.00, 25.00]
        end
      end

      describe 'of months' do
        it 'should return averages for each month' do
          users(:bob).expenses.find_averages_for(:month).should == [7.50, 41.67]
        end
      end
    end

    describe 'when determing the duration since the first entry' do
      describe 'with no entries' do
        before do
          Expense.stub!(:first).and_return(nil)
        end

        it 'should return one' do
          Expense.determine_duration_since_first_entry_in(nil).should == 1
        end
      end

      describe 'with at least one entry' do
        before do
          @first = mock('Expense')
          @first.stub!(:created_at).and_return(60.days.ago)

          Expense.stub!(:first).and_return(@first)
        end

        describe 'in days' do
          it 'should return number of days since first entry' do
            Expense.determine_duration_since_first_entry_in(:day).round.should == 60
          end
        end

        describe 'in weeks' do
          it 'should return number of weeks since first entry' do
            Expense.determine_duration_since_first_entry_in(:week).round.should == 9
          end
        end

        describe 'in months' do
          it 'should return number of months since first entry' do
            Expense.determine_duration_since_first_entry_in(:month).round.should == 2
          end
        end
      end
    end

    describe 'when determing the format for a range' do
      { :day => '%j%Y', :week => '%W%Y', :month => '%m%Y' }.each do |range, format|
        it "should return '#{format}' for #{range}" do
          Expense.determine_format_for(range).should == format
        end
      end
    end

    describe 'when searching' do
      fixtures :expenses

      it 'should find expenses by item' do
        Expense.search('cer').should       == [expenses(:bob_last_week)]
        Expense.search('grocer').should    == [expenses(:bob_last_week)]
        Expense.search('groceries').should == [expenses(:bob_last_week)]
      end

      describe 'and grouping by relative date' do
        it 'should find expenses by item and group by relative date' do
          Expense.search_grouped_by_relative_date('cer').to_a.should == [['Two Weeks Ago', [expenses(:bob_last_week)]]]
        end
      end
    end
  end

  describe 'when being created' do
    it 'should create valid expense' do
      lambda {
        create_expense
      }.should change(Expense, :count).by(1)
    end

    it 'should require user ID' do
      create_expense(:user_id => nil).errors.on(:user_id).should_not be_nil
    end

    it 'should require cost' do
      create_expense(:cost => nil).errors.on(:cost).should_not be_nil
    end

    it 'should require cost to be greater than zero' do
      create_expense(:cost =>  0).errors.on(:cost).should_not be_nil
      create_expense(:cost => -1).errors.on(:cost).should_not be_nil
    end

    it 'should require item' do
      create_expense(:item => nil).errors.on(:item).should_not be_nil
    end

    it 'should allow a cost with a dollar sign' do
      expense = create_expense(:cost => nil, :item => '$5.45 for lunch')
      expense.cost.should == 5.45
    end

    it 'should allow a cost less than a dollar' do
      expense = create_expense(:cost => nil, :item => '.25 for gum')
      expense.cost.should == 0.25
    end

    describe 'with no cost' do
      ['', 'on', 'for'].each do |separator|
        describe "and cost and item separated by '#{separator}" do
          before do
            @expense = create_expense(:cost => nil, :item => "5.45 #{separator} Subway for lunch")
          end

          it 'should extract cost from item' do
            @expense.cost.should == 5.45
          end

          it 'should remove cost from item' do
            @expense.item.should == 'Subway for lunch'
          end
        end
      end
    end
  end

  describe 'instance' do
    fixtures :expenses, :users

    before do
      @expense = expenses(:default)
    end

    it 'should belong to a user' do
      @expense.user.should == users(:default)
    end

    describe 'when determine relative date from today' do
      { 0    => 'Today',
        1    => 'Yesterday',
        2    => 'Last Week',
        7    => 'Two Weeks Ago',
        14   => 'Three Weeks Ago',
        21   => 'Four Weeks Ago',
        30   => 'Last Month',
        60   => 'Two Months Ago',
        90   => 'Three Months Ago',
        120  => 'Four Months Ago',
        140  => 'This Year',
        365  => 'Last Year',
        730  => 'Two Years Ago',
        1095 => 'Several Years Ago'
      }.each do |number_of, group|
        it "should return '#{group}' for #{number_of} days ago" do
          expense = create_expense(:created_at => number_of.days.ago)
          expense.relative_date.should == group
        end
      end
    end
  end

  protected

  def create_expense(options = {})
    returning(new_expense(options)) do |account|
      account.save
    end
  end

  def new_expense(options = {})
    Expense.new(valid_attributes.merge(options))
  end

  def valid_attributes
    { :user_id => 1,
      :cost    => 695.00,
      :item    => 'registration for RailsConf 2009.'
    }
  end
end
