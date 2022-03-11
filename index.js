const express = require('express');
const { JsonWebTokenError } = require('jsonwebtoken');
const { Pool, Client } = require('pg')
const cors = require('cors')

require('dotenv').config();

const jwt = require('jsonwebtoken');


const PORT = process.env?.NODE_ENV || 4000;


const authUser = (req, res, next) => {
    const token = req.headers['authorization'];
    try {
        const decoded = jwt.verify(token, process.env?.KEY);
        req.user = decoded;
        next();
    } catch (err) { 
        return res.status(500).send({
            message: err
        });
    }
}


function initRouters(app, client) {
    
    app.post('/login', async (req, res) => {
        try{
            const {username, password} = req.body;
            const queryResult = (await client.query(`SELECT * FROM "get_user"('${username}', '${password}') LIMIT 1`));
            const result = queryResult.rows[0];
            if(!result) return res.status(401).send({ jwt: null });

            const token = await jwt.sign({ username: result.username, id: result.id }, process.env?.KEY);
            res.send({jwt : token})
            
        } catch (e) {
            res.status(500).send({ message: "internal server error" });
        }

    });

    app.get('/movies', authUser , async (req, res) => {
        const { id } = req.user;
        const result = await client.query(`SELECT  * FROM "getall_movies"(${id})`);
        res.send(result.rows);
    });

    app.get('/movie/:id', authUser , async (req, res) => {
        const {id : movieId} = req.params;
        const {id : userId} = req.user;
        const query = await client.query(`
            SELECT * FROM "get_user_movie"(${parseInt(movieId)}, ${userId}) LIMIT 1
        `);

        const result = query.rows[0];

        res.send(result);
    });

    // bookmark add
    app.post('/bookmark-movie/:id', authUser, async (req, res) => {
        const {id: userId} = req.user;
        const {id: movieId} = req.params;
        const query = await client.query(`
            SELECT "add_or_remove_watchmovie"(${movieId}, ${userId})
        `);
        const result = query.rows[0];
        res.send(result);
    });

    app.put('/set-rating/:id/:rating', authUser, async (req, res) => {
        const { id: movieId, rating } = req.params;
        const { id : userId } = req.user;

        const query = await client.query(`
            SELECT "set_rating"(${movieId}, ${userId}, ${rating})
        `);
        const result = query.rows[0];
        res.send(result);
    });

    app.delete('/delete-rating/:id', authUser, async (req, res) => {
        const { id: movieId } = req.params;
        const { id : userId } = req.user;

        const query = await client.query(`
            SELECT "remove_rating"(${movieId}, ${userId})
        `);
        const result = query.rows[0];
        res.send(result);
    });

    app.get('/movie-suggestions', authUser , async (req, res) => {
        const { id: userId } = req.user;
        const query = await client.query(`
            SELECT * FROM "getall_watchsuggestions"(${userId})
        `);
        const result = query.rows;
        res.send(result);
    });

    app.get('/movie-watched', authUser, async (req, res) => {
        const { id: userId } = req.user;
        const query = await client.query(`
            SELECT * FROM "getall_watchsuggestions"(${userId})
        `);
        const result = query.rows;
        res.send(result);
    });

    app.get('/movie-ratings', authUser, async (req, res) => {
        const { id: userId } = req.user;
        const query = await client.query(`
            SELECT * FROM "getall_movie_ratings"(${userId})
        `);
        const result = query.rows;
        res.send(result);
    });
}



(async () => {
    const client = new Client({
        user: process.env?.USER,
        host: process.env?.HOST,
        database: process.env?.DATABASE,
        password: process.env?.PASSWORD,
        port: parseInt(process.env?.PORT),
    });
    await client.connect();
      
    client.query('SELECT $1::text as message', ['Hello world!']).then(() => {
        const app = express();
        app.use(cors({
            origin: 'http://localhost:3000',
        }))

        app.use(express.json());
        app.use(express.urlencoded({ extended: true}));
        initRouters(app, client);
        app.listen(PORT, () => {
            console.log('app has started');
        });
    }).catch(e => {
        console.log("the server could not connect to the database \n", e);
    });
})();

    // console.log(res.rows[0].message) // Hello world!
    // await client.end()
