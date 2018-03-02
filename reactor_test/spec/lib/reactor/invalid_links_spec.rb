require "spec_helper"

describe "Invalid links", focus: false do
  before do
    @container  = Obj.create!(name: 'linking_deactivated_objects', parent: '/', obj_class: 'PlainObjClass')
    @source     = TestClassWithCustomAttributes.create!(name: 'source', parent: @container, test_attr_linklist: [{title: "", destination: "/this/really/has/to/look/like/a/path/but/must/not/point/to/an/obj"}])
    @new_target = TestClassWithCustomAttributes.create!(name: 'new_target', parent: @container)
    @new_target.valid_from = Time.now - 1.second
    @new_target.save!
    @new_target.reload
  end

  after do
    @source.destroy
    @new_target.destroy
    @container.destroy
  end

  specify do
    expect(@source.test_attr_linklist.length).to eq(0)
    expect(@source.attr_values["test_attr_linklist"].length).to eq(1)

    @source.reload

    expect(@source.test_attr_linklist.length).to eq(0)
    expect(@source.attr_values["test_attr_linklist"].length).to eq(1)

    @source.update_attributes!(test_attr_linklist: [{title: "", destination_object: @new_target.path}])
    @source.resolve_refs!
    expect(Obj.find(@source.id).test_attr_linklist.length).to eq(1)
    expect(@source.attr_values["test_attr_linklist"].length).to eq(1)

    @source.reload

    expect(@source.test_attr_linklist.length).to eq(1)
    expect(@source.attr_values["test_attr_linklist"].length).to eq(1)
  end
end
