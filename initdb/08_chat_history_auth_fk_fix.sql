-- Ensure chat_messages.user_id references auth_users for authenticated chat history
DO $$
DECLARE
    referenced_table text;
BEGIN
    SELECT ccu.table_name
      INTO referenced_table
      FROM information_schema.table_constraints tc
      JOIN information_schema.constraint_column_usage ccu
        ON tc.constraint_name = ccu.constraint_name
     WHERE tc.table_name = 'chat_messages'
       AND tc.constraint_type = 'FOREIGN KEY'
       AND ccu.column_name = 'user_id'
       AND tc.constraint_name = 'chat_messages_user_id_fkey'
     LIMIT 1;

    IF referenced_table = 'users' THEN
        ALTER TABLE chat_messages
          DROP CONSTRAINT chat_messages_user_id_fkey;

        ALTER TABLE chat_messages
          ADD CONSTRAINT chat_messages_user_id_fkey
          FOREIGN KEY (user_id)
          REFERENCES auth_users(id)
          ON DELETE CASCADE;
    END IF;
END $$;
