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

    it "keeps the next parent task waiting after call activity returns" do
      caller_xml = <<~BPMN
        <?xml version="1.0" encoding="UTF-8"?>
        <definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"
                     xmlns:zeebe="http://camunda.org/schema/zeebe/1.0"
                     id="Definitions_1" targetNamespace="http://bpmn.io/schema/bpmn">
          <process id="CallerWithNextTask" isExecutable="true">
            <startEvent id="Start">
              <outgoing>Flow_1</outgoing>
            </startEvent>
            <callActivity id="CallActivity">
              <extensionElements>
                <zeebe:calledElement processId="Callee" propagateAllChildVariables="false" />
              </extensionElements>
              <incoming>Flow_1</incoming>
              <outgoing>Flow_2</outgoing>
            </callActivity>
            <userTask id="AfterCall">
              <incoming>Flow_2</incoming>
              <outgoing>Flow_3</outgoing>
            </userTask>
            <endEvent id="End">
              <incoming>Flow_3</incoming>
            </endEvent>
            <sequenceFlow id="Flow_1" sourceRef="Start" targetRef="CallActivity" />
            <sequenceFlow id="Flow_2" sourceRef="CallActivity" targetRef="AfterCall" />
            <sequenceFlow id="Flow_3" sourceRef="AfterCall" targetRef="End" />
          </process>
        </definitions>
      BPMN

      execution = Context.new([ caller_xml, fixture_source("call_activity_callee_test.bpmn") ])
        .start(process_id: "CallerWithNextTask")

      callee_task = execution.child_by_step_id("CallActivity").child_by_step_id("Task")
      callee_task.signal

      after_call = execution.child_by_step_id("AfterCall")
      _(after_call.waiting?).must_equal true
      _(after_call.terminated?).must_equal false
      _(execution.ended?).must_equal false
      _(execution.waiting_tasks.map { |t| t.step.id }).must_equal [ "AfterCall" ]
    end
  end
end
