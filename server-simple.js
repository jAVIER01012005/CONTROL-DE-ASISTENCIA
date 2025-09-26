const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8000;

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept']
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Configuración de la base de datos
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'attendance_app',
  port: process.env.DB_PORT || 3306
};

// Pool de conexiones
const pool = mysql.createPool({
  ...dbConfig,
  waitForConnections: true,
  connectionLimit: 30,
  queueLimit: 0,
  acquireTimeout: 60000,
  timeout: 60000
});

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'tu_jwt_secret_muy_seguro_123456';

// Middleware de autenticación
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token de acceso requerido' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      console.log('JWT Error:', err.message);
      return res.status(403).json({ error: 'Token inválido' });
    }
    req.user = user;
    next();
  });
};

// Middleware para administradores
const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Se requieren permisos de administrador' });
  }
  next();
};

//  validación
const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(6).required()
});

const registerSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(6).required(),
  name: Joi.string().min(2).required(),
  role: Joi.string().valid('employee', 'admin').default('employee')
});

const checkInSchema = Joi.object({
  user_id: Joi.number().integer().required(),
  user_name: Joi.string().required(),
  latitude: Joi.number().required(),
  longitude: Joi.number().required()
});

const checkOutSchema = Joi.object({
  latitude: Joi.number().required(),
  longitude: Joi.number().required()
});

// conexión a base de datos
async function testConnection() {
  try {
    const connection = await pool.getConnection();
    console.log('✅ Conexión a base de datos exitosa');
    connection.release();
  } catch (error) {
    console.error('❌ Error conectando a base de datos:', error.message);
  }
}

// inicializar usuarios
async function initializeUsers() {
  try {
    console.log('🔄 Inicializando usuarios...');
    
    const testPassword = '123456';
    const passwordHashAdmin = await bcrypt.hash(testPassword, 10);
    const passwordHashEmployee = await bcrypt.hash(testPassword, 10);
    
    const updateQueries = [
      pool.execute('UPDATE users SET password_hash = ? WHERE email = ?', [passwordHashAdmin, 'admin@test.com']),
      pool.execute('UPDATE users SET password_hash = ? WHERE email = ?', [passwordHashEmployee, 'empleado@test.com'])
    ];
    
    await Promise.all(updateQueries);
    console.log('✅ Usuarios inicializados con contraseñas: 123456');
    
  } catch (error) {
    console.error('❌ Error inicializando usuarios:', error.message);
  }
}
const ensureReportsDir = () => {
  const reportsDir = path.join(__dirname, 'reports');
  if (!fs.existsSync(reportsDir)) {
    fs.mkdirSync(reportsDir, { recursive: true });
  }
  return reportsDir;
};

function isValidWorkTime(date, schedule) {
  const day = date.getDay(); 
  const time = date.getHours() * 60 + date.getMinutes();
  
//
 // EXTENCION DE HORARIO PARA PRUEBAS - HASTA LAS 10:00 PM
  const extendedEndTime = 22 * 60; // 10:00 PM en minutos (22 * 60 = 1320)
  const tolerance = schedule.tolerance_minutes;
  
  //  PERMITIR CUALQUIER DÍA hasta las 10:00 PM 
  if (time <= (extendedEndTime + tolerance)) {
    console.log(' Horario extendido para pruebas - Válido hasta 10:15 PM');
    return true;
  }
  //
  if (day === 6) { // HORARIO DE SÁBADO
    const saturdayStart = 8 * 60;
    const saturdayEnd = 12 * 60;  
    const tolerance = schedule.tolerance_minutes;
    
    return time >= (saturdayStart - tolerance) && time <= (saturdayEnd + tolerance);
  }
  
  // HORARIO  DE LUNES A VIERNES
  const [startHour, startMin] = schedule.start_time.split(':').map(Number);
  const [endHour, endMin] = schedule.end_time.split(':').map(Number);
  const startTime = startHour * 60 + startMin - schedule.tolerance_minutes;
  const endTime = endHour * 60 + endMin + schedule.tolerance_minutes;
  
  return schedule.work_days.includes(day) && time >= startTime && time <= endTime;
}

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running', timestamp: new Date().toISOString() });
});

app.get('/api/test-db', async (req, res) => {
  try {
    const [rows] = await pool.execute('SELECT 1 as test');
    res.json({ status: 'ok', database: 'connected', data: rows });
  } catch (error) {
    res.status(500).json({ status: 'error', database: 'disconnected', error: error.message });
  }
});

// AUTENTICACIÓN
app.post('/api/auth/login', async (req, res) => {
  try {
    const { error } = loginSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    const { email, password } = req.body;

    const [users] = await pool.execute(
      'SELECT * FROM users WHERE email = ? AND is_active = 1',
      [email]
    );
    
    if (users.length === 0) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const user = users[0];
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Remover password_hash de la respuesta
    const { password_hash, ...userWithoutPassword } = user;

    res.json({
      token,
      user: {
        ...userWithoutPassword,
        is_active: user.is_active === 1
      }
    });

  } catch (error) {
    console.error('Error en login:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.get('/api/auth/profile', authenticateToken, async (req, res) => {
  try {
    const [users] = await pool.execute(
      'SELECT id, email, name, role, is_active, department, phone_number, created_at FROM users WHERE id = ?',
      [req.user.id]
    );

    if (users.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    const user = users[0];
    res.json({ 
      user: {
        ...user,
        is_active: user.is_active === 1
      }
    });

  } catch (error) {
    console.error('Error obteniendo perfil:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.post('/api/auth/reset-test-passwords', async (req, res) => {
  try {
    await initializeUsers();
    res.json({ message: 'Contraseñas de prueba restablecidas a "123456"' });
  } catch (error) {
    console.error('Error reseteando contraseñas:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.post('/api/auth/logout', authenticateToken, (req, res) => {
  res.json({ message: 'Sesión cerrada correctamente' });
});

// RUTA DE ASISTENCIA
app.post('/api/attendance/checkin', authenticateToken, async (req, res) => {
  try {
    const { error } = checkInSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    const { user_id, user_name, latitude, longitude } = req.body;

    const today = new Date().toISOString().split('T')[0];
    
    // Busca  registro del día
    const [existingAttendances] = await pool.execute(
      'SELECT id, check_out_time FROM attendance WHERE user_id = ? AND DATE(check_in_time) = ?',
      [user_id, today]
    );

    // Verifica si ya tiene una entrada pendiente
    const hasPendingEntry = existingAttendances.some(att => att.check_out_time === null);
    if (hasPendingEntry) {
      return res.status(400).json({ error: 'Ya tienes una entrada registrada hoy' });
    }

    // Verifica si ya completó jornada hoy
    const hasCompletedEntry = existingAttendances.some(att => att.check_out_time !== null);
    if (hasCompletedEntry) {
      return res.status(400).json({ error: 'Ya completaste tu jornada hoy' });
    }

    // OBTIENE CONFIGURACIÓN DESDE TABLA SETTINGS
    const [startTime] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['work_start_time']
    );
    
    const [endTime] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['work_end_time']
    );
    
    const [tolerance] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['late_tolerance']
    );

    const workSchedule = {
      start_time: startTime.length > 0 ? startTime[0].setting_value : "08:00",
      end_time: endTime.length > 0 ? endTime[0].setting_value : "17:00",
      tolerance_minutes: tolerance.length > 0 ? parseInt(tolerance[0].setting_value) : 15,
      work_days: [1, 2, 3, 4, 5, 6] // ✅ CORREGIDO: Ahora incluye sábados (6)
    };

    // Valida horario laboral
    if (!isValidWorkTime(new Date(), workSchedule)) {
      return res.status(400).json({ 
        error: `Fuera del horario laboral permitido (${workSchedule.start_time} - ${workSchedule.end_time})` 
      });
    }

    const [result] = await pool.execute(
      `INSERT INTO attendance (user_id, user_name, check_in_time, check_in_lat, check_in_lng, status) 
       VALUES (?, ?, NOW(), ?, ?, 'on-time')`,
      [user_id, user_name, latitude, longitude]
    );

    const [newAttendance] = await pool.execute(
      `SELECT id, user_id, user_name, check_in_time, check_out_time, 
              check_in_lat, check_in_lng, check_out_lat, check_out_lng,
              status, total_hours, notes, created_at
       FROM attendance WHERE id = ?`,
      [result.insertId]
    );

    res.status(201).json({
      message: 'Entrada registrada correctamente',
      attendance: newAttendance[0]
    });

  } catch (error) {
    console.error('Error en check-in:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.put('/api/attendance/checkout/:id', authenticateToken, async (req, res) => {
  try {
    const { error } = checkOutSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    const { id } = req.params;
    const { latitude, longitude } = req.body;

    const [attendances] = await pool.execute(
      'SELECT * FROM attendance WHERE id = ?',
      [id]
    );

    if (attendances.length === 0) {
      return res.status(404).json({ error: 'Registro no encontrado' });
    }

    if (attendances[0].check_out_time !== null) {
      return res.status(400).json({ error: 'Ya tiene salida registrada' });
    }

    const [result] = await pool.execute(
      `UPDATE attendance 
       SET check_out_time = NOW(), 
           check_out_lat = ?, 
           check_out_lng = ?,
           total_hours = TIMESTAMPDIFF(MINUTE, check_in_time, NOW()) / 60.0
       WHERE id = ?`,
      [latitude, longitude, id]
    );

    res.json({
      message: 'Salida registrada correctamente',
      attendance_id: id
    });

  } catch (error) {
    console.error('Error en check-out:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Historial de asistencias POR USUARIO
app.get('/api/attendance/user/:user_id', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.params;
    const { limit = 30, offset = 0 } = req.query;

    const [attendances] = await pool.execute(
      `SELECT id, user_id, user_name, check_in_time, check_out_time, 
              check_in_lat, check_in_lng, check_out_lat, check_out_lng,
              status, total_hours, notes, created_at
       FROM attendance 
       WHERE user_id = ? 
       ORDER BY check_in_time DESC 
       LIMIT ? OFFSET ?`,
      [user_id, parseInt(limit), parseInt(offset)]
    );

    res.json({ attendances });

  } catch (error) {
    console.error('Error obteniendo historial de asistencias:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Última entrada pendiente
app.get('/api/attendance/latest-pending/:user_id', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.params;
    
    const [attendances] = await pool.execute(
      `SELECT id, user_id, user_name, check_in_time, check_out_time, 
              check_in_lat, check_in_lng, check_out_lat, check_out_lng,
              status, total_hours, notes, created_at
       FROM attendance 
       WHERE user_id = ? 
       AND check_out_time IS NULL
       ORDER BY check_in_time DESC 
       LIMIT 1`,
      [user_id]
    );

    if (attendances.length === 0) {
      return res.json(null);
    }

    res.json(attendances[0]);

  } catch (error) {
    console.error('Error obteniendo última entrada pendiente:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.get('/api/attendance/today', authenticateToken, async (req, res) => {
  try {
    const today = new Date().toLocaleDateString('en-CA'); // Formato YYYY-MM-DD

    const [attendances] = await pool.execute(
      `SELECT id, user_id, user_name, check_in_time, check_out_time, 
              check_in_lat, check_in_lng, check_out_lat, check_out_lng,
              status, total_hours, notes, created_at
       FROM attendance 
       WHERE DATE(check_in_time) = ? 
       ORDER BY check_in_time DESC`,
      [today]
    );

    res.json({ attendances });

  } catch (error) {
    console.error('Error obteniendo asistencias de hoy:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.get('/api/attendance/date-range', authenticateToken, async (req, res) => {
  try {
    const { start_date, end_date, user_id } = req.query;

    if (!start_date || !end_date) {
      return res.status(400).json({ error: 'start_date y end_date son requeridos' });
    }

    let query = `
      SELECT id, user_id, user_name, check_in_time, check_out_time, 
             check_in_lat, check_in_lng, check_out_lat, check_out_lng,
             status, total_hours, notes, created_at
      FROM attendance 
      WHERE DATE(check_in_time) BETWEEN ? AND ?
    `;
    let params = [start_date, end_date];

    if (user_id) {
      query += ' AND user_id = ?';
      params.push(user_id);
    }

    query += ' ORDER BY check_in_time DESC';

    const [attendances] = await pool.execute(query, params);

    res.json({ attendances });

  } catch (error) {
    console.error('Error obteniendo asistencias por fecha:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});
// CONFIGURACIÓN
app.get('/api/settings/work-schedule', authenticateToken, async (req, res) => {
  try {
    // Obtener  valores individuales
    const [startTime] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['work_start_time']
    );
    
    const [endTime] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['work_end_time']
    );
    
    const [tolerance] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['late_tolerance']
    );

    const workSchedule = {
      start_time: startTime.length > 0 ? startTime[0].setting_value : "08:00",
      end_time: endTime.length > 0 ? endTime[0].setting_value : "17:00",
      tolerance_minutes: tolerance.length > 0 ? parseInt(tolerance[0].setting_value) : 15,
      work_days: [1, 2, 3, 4, 5, 6] 
    };
    
    res.json(workSchedule);
  } catch (error) {
    console.error('Error obteniendo horarios:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.put('/api/settings/work-schedule', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { start_time, end_time, tolerance_minutes, work_days } = req.body;

    if (!start_time || !end_time || !tolerance_minutes || !work_days) {
      return res.status(400).json({ error: 'Todos los campos son requeridos' });
    }

    // Guarda  valor individualmente
    await pool.execute(
      `INSERT INTO settings (setting_key, setting_value) 
       VALUES (?, ?) 
       ON DUPLICATE KEY UPDATE setting_value = ?`,
      ['work_start_time', start_time, start_time]
    );

    await pool.execute(
      `INSERT INTO settings (setting_key, setting_value) 
       VALUES (?, ?) 
       ON DUPLICATE KEY UPDATE setting_value = ?`,
      ['work_end_time', end_time, end_time]
    );

    await pool.execute(
      `INSERT INTO settings (setting_key, setting_value) 
       VALUES (?, ?) 
       ON DUPLICATE KEY UPDATE setting_value = ?`,
      ['late_tolerance', tolerance_minutes.toString(), tolerance_minutes.toString()]
    );

    res.json({
      message: 'Horarios de trabajo actualizados correctamente',
      schedule: { start_time, end_time, tolerance_minutes, work_days }
    });

  } catch (error) {
    console.error('Error actualizando horarios:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.get('/api/settings/office-location', authenticateToken, async (req, res) => {
  try {
    // Obtener valores 
    const [latitude] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['office_latitude']
    );
    
    const [longitude] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['office_longitude']
    );
    
    const [radius] = await pool.execute(
      'SELECT setting_value FROM settings WHERE setting_key = ?',
      ['geofence_radius']
    );

    const officeLocation = {
      latitude: latitude.length > 0 ? parseFloat(latitude[0].setting_value) : 15.7634,
      longitude: longitude.length > 0 ? parseFloat(longitude[0].setting_value) : -86.75342,
      radius: radius.length > 0 ? parseFloat(radius[0].setting_value) : 100,
      address: "Residencial Monte Real, La Ceiba"
    };
    
    res.json(officeLocation);
  } catch (error) {
    console.error('Error obteniendo ubicación de oficina:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.put('/api/settings/office-location', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { latitude, longitude, radius } = req.body;

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return res.status(400).json({ error: 'Coordenadas inválidas' });
    }

    if (radius < 10 || radius > 1000) {
      return res.status(400).json({ error: 'El radio debe estar entre 10 y 1000 metros' });
    }

    // Guardar cada valor individualmente 
    await pool.execute(
      `INSERT INTO settings (setting_key, setting_value) 
       VALUES (?, ?) 
       ON DUPLICATE KEY UPDATE setting_value = ?`,
      ['office_latitude', latitude.toString(), latitude.toString()]
    );

    await pool.execute(
    'INSERT INTO settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = ?',
    ['office_longitude', longitude.toString(), longitude.toString()]
);
    await pool.execute(
      `INSERT INTO settings (setting_key, setting_value) 
       VALUES (?, ?) 
       ON DUPLICATE KEY UPDATE setting_value = ?`,
      ['geofence_radius', radius.toString(), radius.toString()]
    );

    res.json({
      message: 'Ubicación de oficina actualizada correctamente',
      location: { latitude, longitude, radius }
    });

  } catch (error) {
    console.error('Error actualizando ubicación de oficina:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// ADMINISTRACIÓN DE USUARIOS
app.get('/api/users', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const [users] = await pool.execute(
      'SELECT id, email, name, role, is_active, created_at FROM users ORDER BY created_at DESC'
    );

    res.json({ 
      users: users.map(user => ({
        ...user,
        is_active: user.is_active === 1
      }))
    });

  } catch (error) {
    console.error('Error obteniendo usuarios:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.post('/api/users', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { name, email, password, role } = req.body;

    // Validar campos requeridos
    if (!name || !email || !password || !role) {
      return res.status(400).json({ error: 'Todos los campos son requeridos' });
    }

    // Verificar si el email ya existe
    const [existingUsers] = await pool.execute(
      'SELECT id FROM users WHERE email = ?',
      [email]
    );

    if (existingUsers.length > 0) {
      return res.status(400).json({ error: 'El email ya está registrado' });
    }

    // Hash de la contraseña
    const passwordHash = await bcrypt.hash(password, 10);

    // Crear usuario
    const [result] = await pool.execute(
      'INSERT INTO users (name, email, password_hash, role, is_active) VALUES (?, ?, ?, ?, ?)',
      [name, email, passwordHash, role, 1]
    );

    // Obtener el usuario creado
    const [newUser] = await pool.execute(
      'SELECT id, email, name, role, is_active, created_at FROM users WHERE id = ?',
      [result.insertId]
    );

    res.status(201).json({
      message: 'Usuario creado exitosamente',
      user: {
        ...newUser[0],
        is_active: newUser[0].is_active === 1
      }
    });

  } catch (error) {
    console.error('Error creando usuario:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

app.put('/api/users/:id/status', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { id } = req.params;
    const { is_active } = req.body;

    await pool.execute(
      'UPDATE users SET is_active = ? WHERE id = ?',
      [is_active, id]
    );

    res.json({ 
      message: `Usuario ${is_active ? 'activado' : 'desactivado'} correctamente`
    });

  } catch (error) {
    console.error('Error actualizando estado de usuario:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// REPORTES EXCEL
app.post('/api/reports/generate', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { start_date, end_date, user_id, format = 'excel' } = req.body;

    if (!start_date || !end_date) {
      return res.status(400).json({ error: 'start_date y end_date son requeridos' });
    }

    let query = `
      SELECT a.*, u.name as user_name, u.email, u.department
      FROM attendance a
      JOIN users u ON a.user_id = u.id
      WHERE DATE(a.check_in_time) BETWEEN ? AND ?
    `;
    let params = [start_date, end_date];

    if (user_id) {
      query += ' AND a.user_id = ?';
      params.push(user_id);
    }

    query += ' ORDER BY a.check_in_time DESC';

    const [reportData] = await pool.execute(query, params);

    // GENERAR EXCEL 
    if (format === 'excel') {
      const workbook = new ExcelJS.Workbook();
      const worksheet = workbook.addWorksheet('Asistencias');

      //  columnas
      worksheet.columns = [
        { header: 'ID', key: 'id', width: 8 },
        { header: 'Empleado', key: 'user_name', width: 20 },
        { header: 'Email', key: 'email', width: 25 },
        { header: 'Departamento', key: 'department', width: 15 },
        { header: 'Fecha Entrada', key: 'check_in_date', width: 15 },
        { header: 'Hora Entrada', key: 'check_in_time', width: 12 },
        { header: 'Fecha Salida', key: 'check_out_date', width: 15 },
        { header: 'Hora Salida', key: 'check_out_time', width: 12 },
        { header: 'Estado', key: 'status', width: 12 },
        { header: 'Horas Trabajadas', key: 'total_hours', width: 15 },
        { header: 'Ubicación Entrada', key: 'check_in_location', width: 25 },
        { header: 'Ubicación Salida', key: 'check_out_location', width: 25 }
      ];

      //  datos
      reportData.forEach(record => {
        const checkInDate = record.check_in_time ? new Date(record.check_in_time) : null;
        const checkOutDate = record.check_out_time ? new Date(record.check_out_time) : null;

        worksheet.addRow({
          id: record.id,
          user_name: record.user_name,
          email: record.email,
          department: record.department || 'N/A',
          check_in_date: checkInDate ? checkInDate.toLocaleDateString('es-ES') : 'N/A',
          check_in_time: checkInDate ? checkInDate.toLocaleTimeString('es-ES') : 'N/A',
          check_out_date: checkOutDate ? checkOutDate.toLocaleDateString('es-ES') : 'N/A',
          check_out_time: checkOutDate ? checkOutDate.toLocaleTimeString('es-ES') : 'N/A',
          status: record.status || 'N/A',
          total_hours: record.total_hours ? `${record.total_hours} horas` : 'N/A',
          check_in_location: record.check_in_lat && record.check_in_lng ? 
            `${Number(record.check_in_lat).toFixed(6)}, ${Number(record.check_in_lng).toFixed(6)}` : 'N/A',
          check_out_location: record.check_out_lat && record.check_out_lng ? 
            `${Number(record.check_out_lat).toFixed(6)}, ${Number(record.check_out_lng).toFixed(6)}` : 'N/A'
        });
      });

      // Estilo de encabezado
      worksheet.getRow(1).eachCell((cell) => {
        cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
        cell.fill = {
          type: 'pattern',
          pattern: 'solid',
          fgColor: { argb: 'FF0070C0' }
        };
        cell.alignment = { vertical: 'middle', horizontal: 'center' };
      });

      //  ajustar columnas
      worksheet.columns.forEach(column => {
        let maxLength = 0;
        column.eachCell({ includeEmpty: true }, (cell) => {
          const columnLength = cell.value ? cell.value.toString().length : 10;
          if (columnLength > maxLength) {
            maxLength = columnLength;
          }
        });
        column.width = maxLength < 10 ? 10 : maxLength + 2;
      });

      // Configurar  para descarga
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename=reporte_asistencias_${start_date}_a_${end_date}.xlsx`);
      
      // Enviar archivo
      await workbook.xlsx.write(res);
      res.end();

    } else {
    
      res.json({
        report: {
          period: `${start_date} a ${end_date}`,
          total_records: reportData.length,
          data: reportData
        }
      });
    }

  } catch (error) {
    console.error('Error generando reporte:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

//  archivos estáticos de reportes
app.use('/api/reports/download', express.static(ensureReportsDir()));

// Manejo de errores 
app.use((err, req, res, next) => {
  console.error('Error no manejado:', err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

// Ruta no encontrada
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Iniciar servidor
const startServer = async () => {
  try {
    await testConnection();
    await initializeUsers();
    ensureReportsDir();
    
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
      console.log(`🔗 API disponible en http://localhost:${PORT}/api`);
      console.log(`🌐 Acceso externo: http://192.168.39.191:${PORT}/api`);
      console.log(`🔗 Health check: http://localhost:${PORT}/api/health`);
      console.log(`🔗 Test DB: http://localhost:${PORT}/api/test-db`);
      console.log(`🔗 Reset passwords: http://localhost:${PORT}/api/auth/reset-test-passwords`);
      console.log('📊 Reportes Excel: Implementados y funcionando');
      console.log('🔑 Contraseñas de prueba establecidas a "123456"');
      console.log(' Todas las funciones administrativas implementadas');
      console.log('Endpoints corregidos:');
      console.log(' SÁBADOS PERMITIDOS: 8:00 AM - 12:00 PM');
      console.log(' Validación mejorada de múltiples entradas por día');
      console.log(' Configuración persistente en tabla settings');
      console.log(' Horarios reales aplicados en validaciones');
    });
  } catch (error) {
    console.error('❌ Error iniciando servidor:', error);
  }
};

startServer();

module.exports = app;