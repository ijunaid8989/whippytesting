defmodule Sync.Repo.Migrations.CreateActivitiesAndActivitiesContactsBackupTable do
  use Ecto.Migration

  def up do
    # create backup table and move data, Then delete those data from activities and activities_contacts tables
    execute("""
     CREATE TABLE backup_activities_contacts AS
     SELECT
       ac.*
     FROM
       activities_contacts ac
       JOIN activities a ON a.id = ac.activity_id
     WHERE
       ac.external_contact_id IS NULL;
    """)

    execute("""
     CREATE TABLE backup_activities AS
     SELECT
       *
     FROM
       activities ac
     WHERE
       external_contact_id IS NULL;
    """)

    execute("""
     DELETE FROM activities_contacts
      USING activities
      WHERE activities.id = activities_contacts.activity_id
      and activities.external_contact_id is NULL;
    """)

    execute("""
     DELETE FROM activities WHERE external_contact_id is NULL;
    """)
  end

  def down do
    # restore from backup tables and delete backup tables
    execute("""
       INSERT INTO activities SELECT * FROM backup_activities;
    """)

    execute("""
       DROP TABLE backup_activities;
    """)

    execute("""
    INSERT INTO activities_contacts SELECT * FROM backup_activities_contacts;
    """)

    execute("""
    DROP TABLE backup_activities_contacts;
    """)
  end
end
