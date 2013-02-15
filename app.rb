require 'sinatra'
require "sqlite3"
require 'bcrypt'

database_file = settings.environment.to_s+".sqlite3"

db = SQLite3::Database.new database_file
db.results_as_hash = true
db.execute "
	CREATE TABLE IF NOT EXISTS guestbook (
		user_id INTEGER,
		message VARCHAR(255)
	);
";

db.execute "
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name VARCHAR(255) UNIQUE,
      pw_hash VARCHAR(255)
	);
";

enable :sessions

get '/' do
	@messages = db.execute("SELECT * FROM guestbook JOIN users ON users.id = guestbook.user_id");
	erb File.read('our_form.erb')
end

post '/' do
	@name = params['name']
	result = db.execute("SELECT * FROM users WHERE name = ?", @name) || []
	if result.length>0
		db.execute(
			"INSERT INTO guestbook VALUES( ?, ? )",
			result.shift['id'], params['message']
		);
		erb File.read('thanks.erb')
	end
end

get '/users/:name' do

	@name = params['name']
	@messages = db.execute("
		SELECT * FROM users 
		JOIN guestbook 
		ON users.id = guestbook.user_id 
		WHERE name = ?
	", params['name'])

	erb File.read('user.erb')

end

get '/users/:name/edit' do

	@name = params['name']
	result = db.execute("SELECT * FROM users WHERE name = ?", params['name'])
	@user = result.shift || false
	erb File.read('user_edit.erb')

end

post '/users/:old_name' do

	db.execute("
		UPDATE users SET name = ? WHERE name = ?;
	", params['name'], params['old_name'])

end

get '/signup' do
   erb File.read('signup.erb')
end

# Create a new user (name, password)
post '/users/' do
   # hash password

   id = db.execute('SELECT count(*) from users where name = ?', params['name'])
   if id and id[0][0] > 0
      @error = "Sorry, that user already exists"
      erb File.read('error.erb')
   else
      pw_hash = BCrypt::Password::create(params['password'])
      db.execute('INSERT into users (name, pw_hash) values (?, ?)',
            params['name'], pw_hash)
   end
      
end

get '/login' do
   erb File.read('login.erb')
end

# Login the user (name, password)
post '/login' do
   rows = db.execute('SELECT id, pw_hash from users where name = ?', params['name'])
   if rows and rows.length > 0
      pw_hash = BCrypt::Password.new(rows[0]['pw_hash'])
      if pw_hash == params['password']
         session['user_id'] = rows[0]['id']
         return "Thank you for logging in, #{params['name']}!"
      else
         @error = "Bad username or password"
         erb File.read('error.erb')
      end
   else
      @error = "Bad username or password"
      erb File.read('error.erb')
   end

end
