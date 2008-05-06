require File.dirname(__FILE__) + '/../test_helper'

class PoolTest < ActiveSupport::TestCase
  fixtures :users, :posts
  
  def create_pool(params = {})
    Pool.create({:user_id => 1, :name => "my pool", :post_count => 0, :is_public => false, :description => "pools"}.merge(params))
  end
  
  def find_post(pool, post_id)
    PoolPost.find(:first, :conditions => ["pool_id = ? AND post_id = ?", pool.id, post_id])
  end
  
  def add_posts(pool)
    pool.add_post(1)
    pool.add_post(2)
    pool.add_post(3)
    pool.add_post(4)
  end
  
  def test_normalize
    pool = create_pool
    assert_equal("my_pool", pool.name)
  end
  
  def test_uniqueness
    pool1 = create_pool
    pool2 = create_pool
    assert_equal(1, Pool.count(["name = 'my_pool'"]))
  end
  
  def test_api
    pool = create_pool
    assert_nothing_raised do
      pool.to_json
    end
    
    assert_nothing_raised do
      pool.to_xml
    end
  end
  
  def test_remove_nonexistent_post
    pool = create_pool
    add_posts(pool)
    
    assert_nothing_raised do
      pool.remove_post(1000)
    end
  end
    
  def test_remove_post_from_head
    pool = create_pool
    add_posts(pool)
    
    pool.remove_post(1)
    assert_equal(3, pool.post_count)
    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    post3 = find_post(pool, 3)
    post4 = find_post(pool, 4)
    assert_nil(post1)
    assert_nil(post2.prev_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_equal(4, post3.next_post_id)
    assert_equal(3, post4.prev_post_id)
    assert_nil(post4.next_post_id)
  end
  
  def test_remove_post_from_middle
    pool = create_pool
    add_posts(pool)
    
    pool.remove_post(2)
    assert_equal(3, pool.post_count)
    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    post3 = find_post(pool, 3)
    post4 = find_post(pool, 4)
    assert_nil(post2)
    assert_nil(post1.prev_post_id)
    assert_equal(3, post1.next_post_id)
    assert_equal(1, post3.prev_post_id)
    assert_equal(4, post3.next_post_id)
    assert_equal(3, post4.prev_post_id)
    assert_nil(post4.next_post_id)
  end
  
  def test_remove_post_from_tail
    pool = create_pool
    add_posts(pool)
    
    pool.remove_post(4)
    assert_equal(3, pool.post_count)
    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    post3 = find_post(pool, 3)
    post4 = find_post(pool, 4)
    assert_nil(post4)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_nil(post3.next_post_id)
  end
  
  def test_add_post
    pool = create_pool
    pool.add_post(1)
    post1 = find_post(pool, 1)
    assert_not_nil(post1)
    assert_equal(1, pool.post_count)
    assert_equal(0, post1.sequence)
    assert_nil(post1.prev_post_id)
    assert_nil(post1.next_post_id)
    
    pool.add_post(2)
    post1.reload
    post2 = find_post(pool, 2)
    assert_not_nil(post2)
    assert_equal(2, pool.post_count)
    assert_equal(0, post1.sequence)
    assert_equal(1, post2.sequence)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(1, post2.prev_post_id)
    assert_nil(post2.next_post_id)
    
    pool.add_post(3)
    post1.reload
    post2.reload
    post3 = find_post(pool, 3)
    assert_not_nil(post3)
    assert_equal(3, pool.post_count)
    assert_equal(0, post1.sequence)
    assert_equal(1, post2.sequence)
    assert_equal(2, post3.sequence)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(1, post2.prev_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_nil(post3.next_post_id)
    
    pool.add_post(4)
    post1.reload
    post2.reload
    post3.reload
    post4 = find_post(pool, 4)
    assert_not_nil(post4)
    assert_equal(4, pool.post_count)
    assert_equal(0, post1.sequence)
    assert_equal(1, post2.sequence)
    assert_equal(2, post3.sequence)
    assert_equal(3, post4.sequence)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(1, post2.prev_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_equal(4, post3.next_post_id)
    assert_equal(3, post4.prev_post_id)
    assert_nil(post4.next_post_id)
  end
  
  def test_add_duplicate
    assert_raise(Pool::PostAlreadyExistsError) do
      pool = create_pool
      add_posts(pool)
      pool.add_post(1)
    end
  end
end
