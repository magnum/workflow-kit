# frozen_string_literal: true

require "test_helper"

module BPMN
  describe :duplicate_element_ids_test do
    # Camunda Modeler copy/paste often reuses StartEvent_1 / Activity_* across files.
    let(:process1_xml) do
      <<~BPMN
        <?xml version="1.0" encoding="UTF-8"?>
        <definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"
                     xmlns:zeebe="http://camunda.org/schema/zeebe/1.0"
                     id="Definitions_1" targetNamespace="http://bpmn.io/schema/bpmn">
          <process id="process1" isExecutable="true">
            <startEvent id="StartEvent_1">
              <outgoing>Flow_1</outgoing>
            </startEvent>
            <userTask id="Activity_shared">
              <extensionElements>
                <zeebe:properties>
                  <zeebe:property name="solver:form" value="yesno" />
                </zeebe:properties>
              </extensionElements>
              <incoming>Flow_1</incoming>
              <outgoing>Flow_2</outgoing>
            </userTask>
            <endEvent id="EndEvent_1">
              <incoming>Flow_2</incoming>
            </endEvent>
            <sequenceFlow id="Flow_1" sourceRef="StartEvent_1" targetRef="Activity_shared" />
            <sequenceFlow id="Flow_2" sourceRef="Activity_shared" targetRef="EndEvent_1" />
          </process>
        </definitions>
      BPMN
    end

    let(:process2_xml) do
      <<~BPMN
        <?xml version="1.0" encoding="UTF-8"?>
        <definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL"
                     xmlns:zeebe="http://camunda.org/schema/zeebe/1.0"
                     id="Definitions_2" targetNamespace="http://bpmn.io/schema/bpmn">
          <process id="process2" isExecutable="true">
            <startEvent id="StartEvent_1">
              <outgoing>Flow_1</outgoing>
            </startEvent>
            <userTask id="Activity_shared">
              <extensionElements>
                <zeebe:properties>
                  <zeebe:property name="solver:form" value="textarea" />
                </zeebe:properties>
              </extensionElements>
              <incoming>Flow_1</incoming>
              <outgoing>Flow_2</outgoing>
            </userTask>
            <endEvent id="EndEvent_1">
              <incoming>Flow_2</incoming>
            </endEvent>
            <sequenceFlow id="Flow_1" sourceRef="StartEvent_1" targetRef="Activity_shared" />
            <sequenceFlow id="Flow_2" sourceRef="Activity_shared" targetRef="EndEvent_1" />
          </process>
        </definitions>
      BPMN
    end

    # Load process2 first so a naive element_by_id would return the wrong form.
    let(:context) { Context.new([ process2_xml, process1_xml ]) }

    it "resolves element_by_id within the requested process" do
      form1 = context.element_by_id("Activity_shared", process_id: "process1")
        .extension_elements.properties["solver:form"]
      form2 = context.element_by_id("Activity_shared", process_id: "process2")
        .extension_elements.properties["solver:form"]

      _(form1).must_equal "yesno"
      _(form2).must_equal "textarea"
    end

    it "restores waiting task properties from the started process after serialize" do
      execution = context.start(process_id: "process1")
      task = execution.waiting_tasks.first

      _(task.step.extension_elements.properties["solver:form"]).must_equal "yesno"

      restored = Context.new([ process2_xml, process1_xml ]).restore(execution.serialize)
      restored_task = restored.waiting_tasks.first

      _(restored_task.step.extension_elements.properties["solver:form"]).must_equal "yesno"
      _(JSON.parse(execution.serialize)["children"].first["process_id"]).must_equal "process1"
    end
  end
end
