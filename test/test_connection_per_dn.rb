require 'al-test-utils'

class TestConnectionPerDN < Test::Unit::TestCase
  include AlTestUtils

  priority :must
  def test_bind_with_empty_password
    make_temporary_user do |user, password|
      assert_equal(user.class.connection, user.connection)
      assert_raises(ActiveLdap::AuthenticationError) do
        user.bind("", :try_sasl => false)
      end
      assert_equal(user.class.connection, user.connection)

      assert_nothing_raised do
        user.bind("", :try_sasl => false, :allow_anonymous => true)
      end
      assert_not_equal(user.class.connection, user.connection)
    end
  end

  priority :normal
  def test_rebind_with_invalid_password
    make_temporary_user do |user, password|
      assert_equal(user.class.connection, user.connection)
      assert_nothing_raised do
        user.bind(password)
      end
      assert_not_equal(user.class.connection, user.connection)

      assert_raises(ActiveLdap::AuthenticationError) do
        user.bind(password + "-WRONG", :try_sasl => false)
      end
    end
  end

  def test_bind
    make_temporary_user do |user, password|
      assert_equal(user.class.connection, user.connection)
      assert_raises(ActiveLdap::AuthenticationError) do
        user.bind(:bind_dn => nil,
                  :try_sasl => false,
                  :allow_anonymous => false,
                  :retry_limit => 0)
      end
      assert_equal(user.class.connection, user.connection)

      assert_nothing_raised do
        user.bind(:bind_dn => nil,
                  :try_sasl => false,
                  :allow_anonymous => true)
      end
      assert_not_equal(user.class.connection, user.connection)

      assert_equal(user.connection, user.class.find(user.dn).connection)
      begin
        assert_equal(user.connection, user.find(user.dn).connection)
      rescue ActiveLdap::EntryNotFound
        omit("requires permission for searching by 'uid' to anonymous user.")
      end
    end
  end

  def test_find
    make_temporary_user do |user, password|
      make_temporary_user do |user2, password2|
        user.bind(password)
        assert_not_equal(user.class.connection, user.connection)

        found_user2 = user.find(user2.dn)
        assert_not_equal(user2.connection, found_user2.connection)
        assert_equal(user.connection, found_user2.connection)

        assert_equal(found_user2.class.connection,
                     found_user2.class.find(found_user2.dn).connection)

        found_user2.bind(password2)
        assert_not_equal(user.connection, found_user2.connection)
        assert_equal(user2.connection, found_user2.connection)
      end
    end
  end

  def test_associations
    make_temporary_user do |user, password|
      make_temporary_group do |group1|
        make_temporary_group do |group2|
          user.groups = [group1]
          assert_equal(group1.connection, user.connection)

          user.bind(password, :try_sasl => false)
          assert_not_equal(user.class.connection, user.connection)
          assert_not_equal(group1.connection, user.connection)
          assert_equal(user.groups[0].connection, user.connection)

          assert_raise(ActiveLdap::OperationNotPermitted) do
            user.groups << group2
          end
          assert_equal([group1.cn], user.groups.collect(&:cn))

          assert_not_equal(group1.connection, user.connection)
          assert_equal(user.groups[0].connection, user.connection)

          found_user = user.class.find(user.dn)
          assert_equal(user.connection, found_user.connection)
          assert_equal(found_user.connection,
                       found_user.groups[0].connection)
        end
      end
    end
  end
end
