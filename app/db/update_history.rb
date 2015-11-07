module DB

  class UpdateHistory
    class << self
      def mark(run_type, start_id = nil, success = true)
        sql = "INSERT INTO update_history (run_type, start_id, successful) VALUES ('#{run_type}', #{start_id.nil? ? 'NULL' : start_id}, #{success ? 1 : 0})"
        DB.client.query(sql)

        return DB::client.last_id
      end

      def last_start(run_type)
        sql = "SELECT max(run_date) AS run_date FROM update_history WHERE run_type = '#{run_type}_start'"
        res = DB.client.query(sql)

        return res.first['run_date']
      end
    end
  end

end
