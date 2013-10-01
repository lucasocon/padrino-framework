module Padrino
  module Reloader
    module Storage
      extend self

      def clear!
        files.each do |file, _|
          remove(file)
          $LOADED_FEATURES.delete(file)
        end
        @files = {}
      end

      def remove(name)
        file = files[name] || return
        file[:constants].each{ |constant| Reloader.remove_constant(constant) }
        file[:features].each{ |feature| $LOADED_FEATURES.delete(feature) }
        files.delete(name)
      end

      def prepare(name)
        remove(name)
        @old_entries ||= {}
        @old_entries[name] = {
          :constants => ObjectSpace.classes,
          :features  => old_features = Set.new($LOADED_FEATURES.dup)
        }
        old_features.include? name
      end

      def commit(name)
        entry = {
          :constants => ObjectSpace.new_classes(@old_entries[name][:constants]),
          :features  => Set.new($LOADED_FEATURES) - @old_entries[name][:features] - [name]
        }
        entry[:features].reject!{ |feature| !Reloader.in_root?(feature) }
        files[name] = entry
        @old_entries.delete(name)
      end

      def rollback(name)
        new_constants = ObjectSpace.new_classes(@old_entries[name][:constants])
        new_constants.each{ |klass| Reloader.remove_constant(klass) }
        @old_entries.delete(name)
      end

      def each(name, type)
        file = files[name] || return
        file[type].each{ |entry| yield(entry) }
      end

      private

      def files
        @files ||= {}
      end
    end
  end
end
