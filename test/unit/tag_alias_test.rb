require File.dirname(__FILE__) + '/../test_helper'

class TagAliasTest < ActiveSupport::TestCase
  def setup
    if CONFIG["enable_caching"]
      MEMCACHE.flush_all
    end
    
    @alias = TagAlias.create(:name => "tag2", :alias => "tag1", :is_pending => false, :reason => "none", :creator_id => 1)
    @test_number = 1
    
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def test_implications
    impl = TagImplication.create(:predicate => "tagb", :consequent => "tagc", :is_pending => false)
    alia = TagAlias.create(:name => "tagb", :alias => "tag1", :is_pending => false, :reason => "none", :creator_id => 1)
    impl.reload
    assert_equal(impl.predicate_id, Tag.find_by_name("tag1").id)
  end

  def test_to_aliased
    assert_equal(["tag1"], TagAlias.to_aliased(["tag2"]))
    assert_equal(["tag3"], TagAlias.to_aliased(["tag3"]))
  end
  
  def test_destroy_and_notify
    @alias.destroy_and_notify(User.find(2), "hohoho")
    assert_not_nil(Dmail.find_by_body("A tag alias you submitted (tag2 &rarr; tag1) was deleted for the following reason: hohoho."))
    assert_nil(TagAlias.find_by_id(@alias.id))
  end
  
  def test_normalize
    hoge = TagAlias.create(:name => "-ho ge", :alias => "tag3", :is_pending => false, :reason => "none", :creator_id => 1)
    assert_equal("ho_ge", hoge.name)
  end
  
  def test_uniqueness
    # Try to prevent cycles from being formed
    hoge = TagAlias.create(:name => "tag1", :alias => "tag3", :is_pending => false, :reason => "none", :creator_id => 1)
    assert_equal(["tag1 is already aliased to something"], hoge.errors.full_messages)
  
    hoge = TagAlias.create(:name => "tag2", :alias => "tag3", :is_pending => false, :reason => "none", :creator_id => 1)
    assert_equal(["tag2 is already aliased to something"], hoge.errors.full_messages)
  end
  
  def test_approve
    p1 = create_post("tag5 tag6 tag7")
    p2 = create_post("tag5")
    p3 = create_post("tag8")
    
    ta = TagAlias.create(:name => "tag5", :alias => "tagx", :is_pending => true, :reason => "none", :creator_id => 1)
    p1.reload
    p2.reload
    p3.reload
    assert_equal("tag5 tag6 tag7", p1.cached_tags)
    assert_equal("tag5", p2.cached_tags)
    assert_equal("tag8", p3.cached_tags)
    ta.approve(1, '127.0.0.1')
    p1.reload
    p2.reload
    p3.reload
    ta.reload
    assert(!ta.is_pending?, "Tag alias should have been marked as not pending")
    assert_equal("tag6 tag7 tagx", p1.cached_tags)
    assert_equal("tagx", p2.cached_tags)
    assert_equal("tag8", p3.cached_tags)
  end
  
  def test_tag_types
    sage = create_tag(:tag_type => 1, :name => "sage")
    ta = TagAlias.create(:name => "sage", :alias => "mage", :is_pending => true, :reason => "none", :creator_id => 1)
    assert_equal(1, ta.alias_tag.tag_type)
  end
  
  def test_api
    assert_nothing_raised {@alias.to_json}
    assert_nothing_raised {@alias.to_xml}
  end
  
  def test_fix
    ta = TagAlias.create(:name => "tag3", :alias => "tag4", :is_pending => false, :reason => "xxx", :creator_id => 1)
    p1 = create_post("tag1")
    ActiveRecord::Base.connection.execute("UPDATE tag_aliases SET name = 'tag1' WHERE id = #{ta.id}")
    Cache.delete("tag_alias:tag1")
    Cache.delete("tag_alias:tag3")
    ta.reload
    p1.reload
    assert_equal("tag1", ta.name)
    assert_equal("tag4", ta.alias_name)
    assert_equal("tag1", p1.cached_tags)
    assert_equal(1, Tag.find_by_name("tag1").post_count)
    assert_equal(0, Tag.find_by_name("tag3").post_count)
    assert_equal(0, Tag.find_by_name("tag4").post_count)
    TagAlias.fix("tag1")
    p1.reload
    assert_equal("tag4", p1.cached_tags)
    assert_equal(0, Tag.find_by_name("tag1").post_count)
    assert_equal(0, Tag.find_by_name("tag3").post_count)
    assert_equal(1, Tag.find_by_name("tag4").post_count)
  end
end
