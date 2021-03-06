require File.expand_path('../../test_helper', __FILE__)

class TranslatedTest < MiniTest::Spec
  def setup
    @previous_backend = I18n.backend
    I18n.pretend_fallbacks
    I18n.backend = BackendWithFallbacks.new

    I18n.locale = :'en-US'
    I18n.fallbacks = ::I18n::Locale::Fallbacks.new
  end

  def teardown
    I18n.fallbacks.clear
    I18n.hide_fallbacks
    I18n.backend = @previous_backend
  end

  it "keeping one field in new locale when other field is changed" do
    I18n.fallbacks.map('de-DE' => [ 'en-US' ])
    post = Post.create :title => 'foo'

    I18n.locale = 'de-DE'
    post.content = 'bar'

    assert_equal 'foo', post.title
  end

  it "modifying non-required field in a new locale" do
    I18n.fallbacks.map 'de-DE' => [ 'en-US' ]
    post = Post.create :title => 'foo'
    I18n.locale = 'de-DE'
    post.content = 'bar'
    assert post.save
  end

  it "resolves a simple fallback" do
    I18n.locale = 'de-DE'
    post = Post.create :title => 'foo'

    I18n.locale = 'de'
    post.title = 'baz'
    post.content = 'bar'
    post.save!

    I18n.locale = 'de-DE'
    assert_equal 'foo', post.title
    assert_equal 'bar', post.content
  end

  it "resolves a simple fallback without reloading" do
    I18n.locale = 'de-DE'
    post = Post.new :title => 'foo'

    I18n.locale = 'de'
    post.title = 'baz'
    post.content = 'bar'

    I18n.locale = 'de-DE'
    assert_equal 'foo', post.title
    assert_equal 'bar', post.content
  end

  it "resolves a complex fallback without reloading" do
    I18n.fallbacks.map 'de' => %w(en he)
    I18n.locale = 'de'
    post = Post.new
    I18n.locale = 'en'
    post.title = 'foo'
    I18n.locale = 'he'
    post.title = 'baz'
    post.content = 'bar'
    I18n.locale = 'de'
    assert_equal 'foo', post.title
    assert_equal 'bar', post.content
  end

  it 'fallbacks with lots of locale switching' do
    I18n.fallbacks.map :'de-DE' => [ :'en-US' ]
    post = Post.create :title => 'foo'

    I18n.locale = :'de-DE'
    assert_equal 'foo', post.title

    I18n.locale = :'en-US'
    post.update_attributes(:title => 'bar')

    I18n.locale = :'de-DE'
    assert_equal 'bar', post.title
  end

  it 'fallbacks with lots of locale switching 2' do
    I18n.fallbacks.map :'de-DE' => [ :'en-US' ]
    child = Child.create :content => 'foo'

    I18n.locale = :'de-DE'
    assert_equal 'foo', child.content

    I18n.locale = :'en-US'
    child.update_attributes(:content => 'bar')

    I18n.locale = :'de-DE'
    assert_equal 'bar', child.content
  end

  it 'fallbacks with nil translations' do
    I18n.fallbacks.map :'de-DE' => [ :'en-US' ]
    post = Post.create :title => 'foo'

    I18n.locale = :'de-DE'
    assert_equal 'foo', post.title

    post.update_attributes :title => nil
    assert_equal 'foo', post.title
  end

  it 'fallbacks with empty translations' do
    I18n.fallbacks.map :'de-DE' => [ :'en-US' ]
    task = Task.create :name => 'foo'

    I18n.locale = :'de-DE'
    assert_equal 'foo', task.name

    task.update_attributes :name => ''
    assert_equal 'foo', task.name
  end

  it 'fallbacks with empty translations 2' do
    I18n.fallbacks.map :'de-DE' => [ :'en-US' ]
    task = Task.create :name => 'foo'
    post = Post.create :title => 'foo'

    I18n.locale = :'de-DE'
    assert_equal 'foo', task.name
    assert_equal 'foo', post.title

    task.update_attributes :name => ''
    assert_equal 'foo', task.name

    post.update_attributes :title => ''
    assert_equal '', post.title
  end

  it 'creating just one translation when fallbacks set' do
    I18n.fallbacks.clear
    I18n.fallbacks.map :de => [ :fr ]
    I18n.locale = :de

    task = Task.new :name => 'foo'
    assert_equal false, task.translations.any?(&:persisted?)
    task.save

    assert_equal [:de], task.translations.map(&:locale).sort
  end

  it 'fallback overwritten in model' do
    I18n.fallbacks.clear
    Task.fallbacks = [:en, :de]
    I18n.locale = :de

    task = Task.create(:name => 'foo')
    assert_equal 'foo', task.name

    I18n.locale = :en
    assert_equal 'foo', task.name
    task.name = 'bar'
    assert_equal 'bar', task.name

    I18n.locale = :fr
    assert_equal 'bar', task.name

    Task.fallbacks = nil
  end

  it 'fallback to each other' do
    I18n.fallbacks.clear
    Globalize.fallbacks = {:en => [:en, :pl], :pl => [:pl, :en]}
    I18n.locale = :en

    en_task = Task.create(:name => 'en_text')
    assert_equal 'en_text', en_task.name

    I18n.locale = :pl

    pl_task = Task.create(:name => 'pl_text')
    assert_equal 'pl_text', pl_task.name
    assert_equal 'en_text', en_task.name

    I18n.locale = :en
    assert_equal 'pl_text', pl_task.name

    Globalize.fallbacks = nil
  end

  it "name_translations should not use fallbacks" do
    I18n.fallbacks.clear
    I18n.fallbacks.map :en => [ :de ]
    I18n.locale = :en

    user = User.create(:name => 'John', :email => 'mad@max.com')
    with_locale(:de) { user.name = nil }
    assert_translated user, :en, :name, 'John'
    assert_translated user, :de, :name, 'John'

    translations = {:en => 'John', :de => nil}.stringify_keys!
    assert_equal translations, user.name_translations
  end
end
# TODO should validate_presence_of take fallbacks into account? maybe we need
#   an extra validation call, or more options for validate_presence_of.

