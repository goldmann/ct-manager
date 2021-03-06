require 'ct-agent/helpers/exec-helper'

module CoolingTower
  describe ExecHelper do
    before(:each) do
      @helper = ExecHelper.new( :log => Logger.new('/dev/null') )
    end

    it "should fail when command doesn't exists" do
      Open4.should_receive( :popen4 ).with('thisdoesntexists').and_raise('abc')

      proc { @helper.execute("thisdoesntexists") }.should raise_error("An error occurred while executing command: 'thisdoesntexists', abc")
    end

    it "should fail when command exit status != 0" do
      open4 = mock(Open4)
      open4.stub!(:exitstatus).and_return(1)

      Open4.should_receive( :popen4 ).with('abc').and_return(open4)

      proc { @helper.execute("abc") }.should raise_error("An error occurred while executing command: 'abc', process exited with wrong exit status: 1")
    end

    it "should execute the command" do
      open4 = mock(Open4)
      open4.stub!(:exitstatus).and_return(0)

      Open4.should_receive( :popen4 ).with('abc').and_return(open4)

      proc { @helper.execute("abc") }.should_not raise_error
    end

    it "should execute the command and return output" do
      @helper.execute("ls #{File.dirname( __FILE__ )}/../rspec/ls | wc -l").should == "2"
    end

    it "should execute the command and return multi line output" do
      @helper.execute("ls -1 #{File.dirname( __FILE__ )}/../rspec/ls").should == "one\ntwo"
    end
  end
end
