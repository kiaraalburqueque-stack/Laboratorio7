"""Genera una colección reproducible de Postman con la matriz de permisos."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATHS = ['/api/free', '/client/home', '/management/dashboard', '/manager/reportes']
ACCOUNTS = [
    ('Invitado', None, None, [200, 401, 401, 401]),
    ('USER', 'user', '{{userPassword}}', [200, 200, 403, 403]),
    ('ADMIN', 'admin', '{{adminPassword}}', [200, 200, 200, 200]),
    ('MANAGER', 'manager', '{{managerPassword}}', [200, 403, 403, 200]),
]
MESSAGES = {
    '/api/free': 'Endpoint público funcionando',
    '/client/home': 'Bienvenido USER',
    '/management/dashboard': 'Bienvenido ADMIN',
    '/manager/reportes': 'Reportes disponibles para MANAGER',
}


def item(path, status, username=None, password=None, label=None):
    auth = {'type': 'noauth'} if username is None else {'type': 'basic', 'basic': [
        {'key': 'username', 'value': username, 'type': 'string'},
        {'key': 'password', 'value': password, 'type': 'string'},
    ]}
    assertions = [f'pm.test("HTTP {status}", function () {{ pm.response.to.have.status({status}); }});']
    if status == 200 and path in MESSAGES:
        assertions.append('pm.test("Mensaje correcto", function () { pm.expect(pm.response.text()).to.eql('
                          + json.dumps(MESSAGES[path], ensure_ascii=False) + '); });')
    if status == 200 and path == '/api/me':
        assertions.extend([
            'pm.test("Usuario correcto", function () { pm.expect(pm.response.json().username).to.eql('
            + json.dumps(username) + '); });',
            'pm.test("Sin contraseña en respuesta", function () { pm.expect(pm.response.json()).not.to.have.property("password"); });',
        ])
    return {'name': label or f'{path} → {status}',
            'request': {'method': 'GET', 'header': [], 'auth': auth,
                        'url': {'raw': '{{baseUrl}}' + path, 'host': ['{{baseUrl}}'],
                                'path': path.strip('/').split('/')}},
            'event': [{'listen': 'test', 'script': {'type': 'text/javascript', 'exec': assertions}}]}


collection = {
    'info': {'name': 'Semana 07 - Access Lab',
             'description': 'Matriz de permisos, login real, contraseñas antiguas y rutas eliminadas. Credenciales solo de demostración.',
             'schema': 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},
    'variable': [{'key': 'baseUrl', 'value': 'http://localhost:8080'},
                 {'key': 'userPassword', 'value': 'UsuarioS07!2026'},
                 {'key': 'adminPassword', 'value': 'AdminS07!2026'},
                 {'key': 'managerPassword', 'value': 'ManagerS07!2026'}],
    'item': [],
}
for label, username, password, statuses in ACCOUNTS:
    collection['item'].append({'name': f'Acceso {label}',
                               'item': [item(path, status, username, password)
                                        for path, status in zip(PATHS, statuses)]})
collection['item'].append({'name': 'Autenticación', 'item': [item('/api/me', 401)] +
                          [item('/api/me', 200, username, password, f'Perfil {label}')
                           for label, username, password, _ in ACCOUNTS[1:]]})
collection['item'].append({'name': 'Claves antiguas e inválidas', 'item': [
    item('/client/home', 401, 'user', '1234', 'Contraseña original de user rechazada'),
    item('/management/dashboard', 401, 'admin', '123456', 'Contraseña original de admin rechazada'),
    item('/manager/reportes', 401, 'manager', 'incorrecta', 'Clave incorrecta de manager rechazada'),
    item('/client/home', 401, 'desconocido', 'incorrecta', 'Usuario inexistente rechazado'),
]})
collection['item'].append({'name': 'Rutas anteriores eliminadas', 'item': [
    item(path, 404, 'admin', '{{adminPassword}}')
    for path in ['/public/hello', '/user/dashboard', '/admin/panel']
]})
(ROOT / 'postman').mkdir(exist_ok=True)
(ROOT / 'postman' / 'Semana07.postman_collection.json').write_text(
    json.dumps(collection, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Colección generada: 27 solicitudes.')
