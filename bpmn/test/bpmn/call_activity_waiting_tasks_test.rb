# frozen_string_literal: true

require "test_helper"

module BPMN
  describe :call_activity_waiting_tasks_test do
    let(:sources) do
      [
        fixture_source("call_activity_caller_test.bpmn"),
        fixture_source("call_activity_callee_test.bpmn")
      ]
    end
    let(:context) { Context.new(sources) }

    it "exposes callee waiting tasks on the root execution" do
      execution = context.start(process_id: "Caller")
      call_activity = execution.child_by_step_id("CallActivity")
      callee_task = call_activity.child_by_step_id("Task")

      _(call_activity.waiting?).must_equal true
      _(callee_task.waiting?).must_equal true
      _(execution.waiting_tasks.map { |t| t.step.id }).must_equal [ "Task" ]

      callee_task.signal
      _(execution.ended?).must_equal true
    end
  end
end
