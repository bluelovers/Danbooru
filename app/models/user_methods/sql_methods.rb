module UserMethods
  module SqlMethods
    module ClassMethods
      def generate_sql(params)
        return Nagato::Builder.new do |builder, cond|
          if params[:name]
            cond.add "name ILIKE ? ESCAPE E'\\\\'", "%" + params[:name].tr(" ", "_").to_escaped_for_sql_like + "%"
          end

          if params[:level] && params[:level] != "any"
            cond.add "level = ?", params[:level]
          end

          cond.add_unless_blank "id = ?", params[:id]

          case params[:order]
          when "name"
            builder.order "lower(name)"

          when "posts"
            builder.order "(SELECT count(*) FROM posts WHERE user_id = users.id) DESC"

          when "favorites"
            builder.order "(SELECT count(*) FROM favorites WHERE user_id = users.id) DESC"

          when "notes"
            builder.order "(SELECT count(*) FROM note_versions WHERE user_id = users.id) DESC"

          else
            builder.order "id DESC"
          end
        end.to_hash
      end
    end
    
    def self.included(m)
      m.extend(ClassMethods)
    end
  end
end
