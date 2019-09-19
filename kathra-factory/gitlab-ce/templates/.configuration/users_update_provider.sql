# To connect to a local gitlab postgreSQL database, run the following command :
# gitlab-psql -d gitlabhq_production
update identities set provider='KATHRA';
update identities set extern_uid=subquery.username from (select username,id from users) as subquery where subquery.id=identities.user_id;