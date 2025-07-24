defmodule Sync.Repo.Migrations.FixWhippyAssociationsInExternalCustomProperties do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE custom_properties
    SET external_custom_property = jsonb_set(
      external_custom_property,
      '{whippy_associations}',
      jsonb_build_array(external_custom_property->'whippy_associations')
    )
    WHERE jsonb_typeof(external_custom_property->'whippy_associations') = 'object';
    """)
  end

  def down do
    :ok
  end
end
