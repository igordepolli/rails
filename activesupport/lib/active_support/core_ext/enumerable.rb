# frozen_string_literal: true

module ActiveSupport
  module EnumerableCoreExt # :nodoc:
    module Constants
      private
        def const_missing(name)
          if name == :SoleItemExpectedError
            ::ActiveSupport::EnumerableCoreExt::SoleItemExpectedError
          else
            super
          end
        end
    end
  end
end

module Enumerable
  # Error generated by +sole+ when called on an enumerable that doesn't have
  # exactly one item.
  class SoleItemExpectedError < StandardError; end

  # HACK: For performance reasons, Enumerable shouldn't have any constants of its own.
  # So we move SoleItemExpectedError into ActiveSupport::EnumerableCoreExt.
  ActiveSupport::EnumerableCoreExt::SoleItemExpectedError = remove_const(:SoleItemExpectedError)
  singleton_class.prepend(ActiveSupport::EnumerableCoreExt::Constants)

  # Calculates the minimum from the extracted elements.
  #
  #   payments = [Payment.new(5), Payment.new(15), Payment.new(10)]
  #   payments.minimum(:price) # => 5
  def minimum(key)
    map(&key).min
  end

  # Calculates the maximum from the extracted elements.
  #
  #   payments = [Payment.new(5), Payment.new(15), Payment.new(10)]
  #   payments.maximum(:price) # => 15
  def maximum(key)
    map(&key).max
  end

  # Convert an enumerable to a hash, using the block result as the key and the
  # element as the value.
  #
  #   people.index_by(&:login)
  #   # => { "nextangle" => <Person ...>, "chade-" => <Person ...>, ...}
  #
  #   people.index_by { |person| "#{person.first_name} #{person.last_name}" }
  #   # => { "Chade- Fowlersburg-e" => <Person ...>, "David Heinemeier Hansson" => <Person ...>, ...}
  def index_by
    if block_given?
      result = {}
      each { |elem| result[yield(elem)] = elem }
      result
    else
      to_enum(:index_by) { size if respond_to?(:size) }
    end
  end

  # Convert an enumerable to a hash, using the element as the key and the block
  # result as the value.
  #
  #   post = Post.new(title: "hey there", body: "what's up?")
  #
  #   %i( title body ).index_with { |attr_name| post.public_send(attr_name) }
  #   # => { title: "hey there", body: "what's up?" }
  #
  # If an argument is passed instead of a block, it will be used as the value
  # for all elements:
  #
  #   %i( created_at updated_at ).index_with(Time.now)
  #   # => { created_at: 2020-03-09 22:31:47, updated_at: 2020-03-09 22:31:47 }
  def index_with(default = (no_default = true))
    if block_given?
      result = {}
      each { |elem| result[elem] = yield(elem) }
      result
    elsif no_default
      to_enum(:index_with) { size if respond_to?(:size) }
    else
      result = {}
      each { |elem| result[elem] = default }
      result
    end
  end

  # Returns +true+ if the enumerable has more than 1 element. Functionally
  # equivalent to <tt>enum.to_a.size > 1</tt>. Can be called with a block too,
  # much like any?, so <tt>people.many? { |p| p.age > 26 }</tt> returns +true+
  # if more than one person is over 26.
  def many?
    cnt = 0
    if block_given?
      any? do |*args|
        cnt += 1 if yield(*args)
        cnt > 1
      end
    else
      any? { (cnt += 1) > 1 }
    end
  end

  # Returns a new array that includes the passed elements.
  #
  #   [ 1, 2, 3 ].including(4, 5)
  #   # => [ 1, 2, 3, 4, 5 ]
  #
  #   ["David", "Rafael"].including %w[ Aaron Todd ]
  #   # => ["David", "Rafael", "Aaron", "Todd"]
  def including(*elements)
    to_a.including(*elements)
  end

  # The negative of the <tt>Enumerable#include?</tt>. Returns +true+ if the
  # collection does not include the object.
  def exclude?(object)
    !include?(object)
  end

  # Returns a copy of the enumerable excluding the specified elements.
  #
  #   ["David", "Rafael", "Aaron", "Todd"].excluding "Aaron", "Todd"
  #   # => ["David", "Rafael"]
  #
  #   ["David", "Rafael", "Aaron", "Todd"].excluding %w[ Aaron Todd ]
  #   # => ["David", "Rafael"]
  #
  #   {foo: 1, bar: 2, baz: 3}.excluding :bar
  #   # => {foo: 1, baz: 3}
  def excluding(*elements)
    elements.flatten!(1)
    reject { |element| elements.include?(element) }
  end
  alias :without :excluding

  # Extract the given key from each element in the enumerable.
  #
  #   [{ name: "David" }, { name: "Rafael" }, { name: "Aaron" }].pluck(:name)
  #   # => ["David", "Rafael", "Aaron"]
  #
  #   [{ id: 1, name: "David" }, { id: 2, name: "Rafael" }].pluck(:id, :name)
  #   # => [[1, "David"], [2, "Rafael"]]
  def pluck(*keys)
    if keys.many?
      map { |element| keys.map { |key| element[key] } }
    else
      key = keys.first
      map { |element| element[key] }
    end
  end

  # Extract the given key from the first element in the enumerable.
  #
  #   [{ name: "David" }, { name: "Rafael" }, { name: "Aaron" }].pick(:name)
  #   # => "David"
  #
  #   [{ id: 1, name: "David" }, { id: 2, name: "Rafael" }].pick(:id, :name)
  #   # => [1, "David"]
  def pick(*keys)
    return if none?

    if keys.many?
      keys.map { |key| first[key] }
    else
      first[keys.first]
    end
  end

  # Returns a new +Array+ without the blank items.
  # Uses Object#blank? for determining if an item is blank.
  #
  #   [1, "", nil, 2, " ", [], {}, false, true].compact_blank
  #   # =>  [1, 2, true]
  #
  #   Set.new([nil, "", 1, false]).compact_blank
  #   # => [1]
  #
  # When called on a +Hash+, returns a new +Hash+ without the blank values.
  #
  #   { a: "", b: 1, c: nil, d: [], e: false, f: true }.compact_blank
  #   # => { b: 1, f: true }
  def compact_blank
    reject(&:blank?)
  end

  # Returns a new +Array+ where the order has been set to that provided in the +series+, based on the +key+ of the
  # objects in the original enumerable.
  #
  #   [ Person.find(5), Person.find(3), Person.find(1) ].in_order_of(:id, [ 1, 5, 3 ])
  #   # => [ Person.find(1), Person.find(5), Person.find(3) ]
  #
  # If the +series+ include keys that have no corresponding element in the Enumerable, these are ignored.
  # If the Enumerable has additional elements that aren't named in the +series+, these are not included in the result, unless
  # the +filter+ option is set to +false+.
  def in_order_of(key, series, filter: true)
    if filter
      group_by(&key).values_at(*series).flatten(1).compact
    else
      group_by(&key).values.flatten(1).sort_by { |v| series.index(v.public_send(key)) || series.size }.compact
    end
  end

  # Returns the sole item in the enumerable. If there are no items, or more
  # than one item, raises +Enumerable::SoleItemExpectedError+.
  #
  #   ["x"].sole          # => "x"
  #   Set.new.sole        # => Enumerable::SoleItemExpectedError: no item found
  #   { a: 1, b: 2 }.sole # => Enumerable::SoleItemExpectedError: multiple items found
  def sole
    case count
    when 1   then return first # rubocop:disable Style/RedundantReturn
    when 0   then raise ActiveSupport::EnumerableCoreExt::SoleItemExpectedError, "no item found"
    when 2.. then raise ActiveSupport::EnumerableCoreExt::SoleItemExpectedError, "multiple items found"
    end
  end
end

class Hash
  # Hash#reject has its own definition, so this needs one too.
  def compact_blank # :nodoc:
    reject { |_k, v| v.blank? }
  end

  # Removes all blank values from the +Hash+ in place and returns self.
  # Uses Object#blank? for determining if a value is blank.
  #
  #   h = { a: "", b: 1, c: nil, d: [], e: false, f: true }
  #   h.compact_blank!
  #   # => { b: 1, f: true }
  def compact_blank!
    # use delete_if rather than reject! because it always returns self even if nothing changed
    delete_if { |_k, v| v.blank? }
  end
end

class Range # :nodoc:
  # Optimize range sum to use arithmetic progression if a block is not given and
  # we have a range of numeric values.
  def sum(initial_value = 0)
    if block_given? || !(first.is_a?(Integer) && last.is_a?(Integer))
      super
    else
      actual_last = exclude_end? ? (last - 1) : last
      if actual_last >= first
        sum = initial_value || 0
        sum + (actual_last - first + 1) * (actual_last + first) / 2
      else
        initial_value || 0
      end
    end
  end
end

class Array # :nodoc:
  # Removes all blank elements from the +Array+ in place and returns self.
  # Uses Object#blank? for determining if an item is blank.
  #
  #   a = [1, "", nil, 2, " ", [], {}, false, true]
  #   a.compact_blank!
  #   # =>  [1, 2, true]
  def compact_blank!
    # use delete_if rather than reject! because it always returns self even if nothing changed
    delete_if(&:blank?)
  end
end
