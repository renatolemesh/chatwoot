class AddWidgetTemplateToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :widget_template, :string, default: 'default'
  end
end
