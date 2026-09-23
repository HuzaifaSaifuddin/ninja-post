Implement the following project in Ruby.

It is required to create a JSON API service in Ruby without using Ruby on Rails.

Entities:

1. User

- Has only a login.

2. Post

- Belongs to the user.
- Has a title.
- Has content.
- Has author's IP, saved separately for each post.

3. Rating

- Belongs to the post.
- Accepts a value from 1 to 5.

Actions:

1. Create a post

It should:

- Accept the title and content of the post (cannot be empty), as well as the author's login and IP.
- If there is no author with this username yet, it should be created.
- Return either post attributes with status 200 or validation errors with status 422.

2. Rate the post

It should:

- Accept post ID and value.
- Return a new average post rating.
- The action must work correctly for any number of concurrent requests to

3. Get the top N posts by average rating

Return an array of objects with headings and content.

4. Get a list of IPs from which several different authors posted

Return an array of objects with:

- IP
- an array of author logins

5. Add feedback

Feedback has many posts and users, and has:

- owner_id
- comment (text)

It should:

- Accept user_id or post_id, comment, and owner_id.
- Check if the post or user already has feedback from the same owner.
- Return the feedback list from the same owner.

6. Seeds

Add seeds to:

- Generate 10,000 post feedback records with random text.
- Generate 50 user feedback records with random text.
- Have at least 200,000 posts in the database.
- Preferably have around 100 authors.
- Use 50 different IPs.

Actions should work fast enough on standard hardware both for the specifiehan 100 ms), and for much more. There should be a good margin in terms ofquery optimization.

To achieve this, data denormalization and any other necessary database techniques can be used.

7. Specs

Cover the main parts of the project with specs.

8. Worker

Create a worker that will execute every day at 9 AM and generate an XML file with all feedbacks.

The XML should contain:

- owner login
- comment
- rating (empty if user feedback)
- feedback type (post or user)

Additional requirements:

- Avoid frameworks like Ruby on Rails, Sinatra, etc.
- Do not use generators and generally avoid unnecessary garbage files in the repository.
- You can use any necessary gem.
- Organize the service architecture as you wish.

Implement the project completely.

Before finishing, run the test suite and verify that the main API actions, seeds, concurrent rating behavior, and worker work correctly.