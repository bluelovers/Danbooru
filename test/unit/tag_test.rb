require File.dirname(__FILE__) + '/../test_helper'

class TagTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    MEMCACHE.flush_all
    @test_number = 1
  end

  def test_api
    tag = create_tag(:name => "t1")
    assert_nothing_raised {tag.to_json}
    assert_nothing_raised {tag.to_xml}
  end
  
  def test_count_by_period
    p1 = create_post("tag1", :created_at => 10.days.ago)
    p2 = create_post("tag1")
    p3 = create_post("tag1 tag2")
    
    results = Tag.count_by_period(3.days.ago, Time.now).sort {|a, b| a.to_s <=> b.to_s}
    assert_equal("2", results[0][1])
    assert_equal("tag1", results[0][0])
    assert_equal("1", results[1][1])
    assert_equal("tag2", results[1][0])
  
    results = Tag.count_by_period(20.days.ago, 5.days.ago).sort {|a, b| a.to_s <=> b.to_s}
    assert_equal("1", results[0][1])
    assert_equal("tag1", results[0][0])
  end
  
  def test_find_or_create_by_name
    t = Tag.find_or_create_by_name("-ho-ge")
    assert_nil(Tag.find_by_name("-ho-ge"))
    assert_not_nil(Tag.find_by_name("ho-ge"))
    t = Tag.find_by_name("ho-ge")
    assert_equal(CONFIG["tag_types"]["General"], t.tag_type)
    assert(!t.is_ambiguous?, "Tag should not be ambiguous")
    
    t = Tag.find_or_create_by_name("ambiguous:ho-ge")
    t = Tag.find_by_name("ho-ge")
    assert_equal(CONFIG["tag_types"]["General"], t.tag_type)
    assert(t.is_ambiguous?, "Tag should be ambiguous")
    
    t = Tag.find_or_create_by_name("artist:ho-ge")
    t = Tag.find_by_name("ho-ge")
    assert_equal(CONFIG["tag_types"]["Artist"], t.tag_type)
    
    t = Tag.find_or_create_by_name("artist:mogemoge")
    t = Tag.find_by_name("mogemoge")
    assert_equal(CONFIG["tag_types"]["Artist"], t.tag_type)
    
    ta = TagAlias.create(:name => "moge", :alias => "soge", :is_pending => false, :reason => "none", :creator_id => 1)
    t = Tag.find_or_create_by_name("artist:moge")
    t = Tag.find_by_name("moge")
    assert_equal(CONFIG["tag_types"]["General"], t.tag_type)
    t = Tag.find_by_name("soge")
    assert_equal(CONFIG["tag_types"]["Artist"], t.tag_type)
  end
  
  def test_select_ambiguous
    Tag.find_or_create_by_name("ambiguous:moge")
    Tag.find_or_create_by_name("chichi")
    assert_equal([], Tag.select_ambiguous([]))
    assert_equal(["moge"], Tag.select_ambiguous(["moge", "chichi", "oppai"]))
  end
  
  if CONFIG["enable_caching"]
    def test_cache
      Tag.find_or_create_by_name("artist:a1")
      assert_equal("artist", Cache.get("tag_type:a1"))
    end
  end

  def test_parse_cast
    assert_equal(42, Tag.parse_cast('42', :integer))
    assert_equal(0.42, Tag.parse_cast('0.42', :float))

    assert_equal(1024, Tag.parse_cast('1024',  :filesize))
    assert_equal(1024, Tag.parse_cast('1024b', :filesize))
    assert_equal(1024, Tag.parse_cast('1024B', :filesize))

    assert_equal(1024, Tag.parse_cast('1k',    :filesize))
    assert_equal(1024, Tag.parse_cast('1.K',   :filesize))
    assert_equal(1024, Tag.parse_cast('1.0kb', :filesize))
    assert_equal(1024, Tag.parse_cast('1.0kB', :filesize))
    assert_equal(512,  Tag.parse_cast('0.5Kb', :filesize))
    assert_equal(512,  Tag.parse_cast('.5KB',  :filesize))

    assert_equal(1.5 * 1024 * 1024,  Tag.parse_cast('1.5m', :filesize))
    assert_equal(1.5 * 1024 * 1024,  Tag.parse_cast('1.5M', :filesize))
  end

  def test_parse_query
    results = Tag.parse_query("tag1 tag2")
    assert_equal(["tag1", "tag2"], results[:related])
    assert_equal([], results[:include])
    assert_equal([], results[:exclude])

    results = Tag.parse_query("tag1 -tag2")
    assert_equal(["tag1"], results[:related])
    assert_equal([], results[:include])
    assert_equal(["tag2"], results[:exclude])

    results = Tag.parse_query("tag1 ~tag2")
    assert_equal(["tag1"], results[:related])
    assert_equal(["tag2"], results[:include])
    assert_equal([], results[:exclude])
    
    results = Tag.parse_query("user:bof")
    assert_equal([], results[:related])
    assert_equal([], results[:include])
    assert_equal([], results[:exclude])
    assert_equal("bof", results[:user])
    
    results = Tag.parse_query("id:5")
    assert_equal([:eq, 5], results[:post_id])

    results = Tag.parse_query("id:5..")
    assert_equal([:gte, 5], results[:post_id])

    results = Tag.parse_query("id:..5")
    assert_equal([:lte, 5], results[:post_id])

    results = Tag.parse_query("id:5..10")
    assert_equal([:between, 5, 10], results[:post_id])

    results = Tag.parse_query("filesize:0.5k..1.0M")
    assert_equal([:between, 512, 1024 * 1024], results[:filesize])
    
    # Test aliasing & implications
    tag_z = Tag.find_or_create_by_name("tag-z")
    TagAlias.create(:name => "tag-x", :alias_id => tag_z.id, :is_pending => false, :reason => "none", :creator_id => 1)
    tag_a = Tag.find_or_create_by_name("tag-a")
    tag_b = Tag.find_or_create_by_name("tag-b")
    TagImplication.create(:predicate_id => tag_a.id, :consequent_id => tag_b.id, :is_pending => false)
    
    results = Tag.parse_query("tag-x")
    assert_equal(["tag-z"], results[:related])

    results = Tag.parse_query("-tag-x")
    assert_equal(["tag-z"], results[:exclude])
    
    results = Tag.parse_query("tag-a")
    assert_equal(["tag-a"], results[:related])
  end
  
  def test_related
    p1 = create_post("tag1 tag2")
    p2 = create_post('tag1 tag2 tag3')
    
    t = Tag.find_by_name("tag1")
    related = t.related(true).sort {|a, b| a[0] <=> b[0]}
    assert_equal(["tag1", "2", "0"], related[0])
    assert_equal(["tag2", "2", "0"], related[1])
    assert_equal(["tag3", "1", "0"], related[2])
    
    # Make sure the related tags are cached
    p3 = create_post("tag1 tag4")
    t.reload
    related = t.related(true).sort {|a, b| a[0] <=> b[0]}
    assert_equal(3, related.size)
    assert_equal(["tag1", "2", "0"], related[0])
    assert_equal(["tag2", "2", "0"], related[1])
    assert_equal(["tag3", "1", "0"], related[2])
    
    # Make sure related tags are properly updated with the cache is expired
    t.update_attribute(:cached_related_expires_on, 5.days.ago)
    t.reload
    related = t.related(true).sort {|a, b| a[0] <=> b[0]}
    assert_equal(4, related.size)
    assert_equal(["tag1", "3", "0"], related[0])
    assert_equal(["tag2", "2", "0"], related[1])
    assert_equal(["tag3", "1", "0"], related[2])
    assert_equal(["tag4", "1", "0"], related[3])
  end
  
  def test_related_by_type
    p1 = create_post("tag1 artist:tag2")
    p2 = create_post('tag1 tag2 artist:tag3 copyright:tag4')
    
    related = Tag.calculate_related_by_type("tag1", CONFIG["tag_types"]["Artist"]).sort {|a, b| a[0] <=> b[0]}
    assert_equal(2, related.size)
    assert_equal("tag2", related[0][0])
    assert_equal("2", related[0][1])
    assert_equal("tag3", related[1][0])
    assert_equal("1", related[1][1])
  end
  
  def test_types
    t = Tag.find_or_create_by_name("artist:foo")
    assert_equal("artist", t.type_name)
  end
  
  def test_suggestions
    create_post("julius_caesar")
    create_post("julian")
    
    assert_equal(["julius_caesar"], Tag.find_suggestions("caesar_julius"))
    assert_equal(["julian", "julius_caesar"], Tag.find_suggestions("juli"))
  end
end
