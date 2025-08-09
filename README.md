# S886 VESC LISP Control Script

## English

### Description
This LISP script is designed for VESC (Vedder Electronic Speed Controller) motor controllers to interface with external devices via UART communication. The script enables speed control, temperature monitoring, and various safety features for electric vehicles or e-bikes.

### Main Features

1. **UART Communication**
   - Handles UART communication at 9600 baud rate
   - Supports both standard VESC and Express hardware variants
   - Implements CRC error checking for data integrity

2. **Speed Control**
   - Receives throttle commands via UART
   - Converts throttle values to motor current control
   - Calculates speed impulses based on wheel diameter
   - Supports speed limiting (default 25 km/h, can be increased to 50 km/h)

3. **Temperature Monitoring**
   - Reads temperature from ADC channel 3 (LM35Z sensor)
   - Averages temperature readings over 20 samples
   - Overrides motor temperature protection

4. **Safety Features**
   - CRC validation for all incoming data
   - Automatic ADC override when throttle exceeds 50%
   - Mode switching detection with speed limit unlock
   - Error handling for corrupted data

5. **Special Functions**
   - Speed-based audio feedback (tone generation)
   - Mode switching counter for speed limit adjustment
   - Real-time speed calculation and display

### Protocol Details

**Receive Buffer (20 bytes):**
- Byte 0: Header (must be 1)
- Byte 1: Length (must be 20)
- Byte 4: Current mode
- Bytes 7-8: Wheel diameter (big-endian)
- Bytes 16-17: Throttle value (little-endian)
- Byte 19: CRC checksum

**Transmit Buffer (14 bytes):**
- Fixed header: `0x02 0x0E 0x01 0x00 0x80 0x00 0x00 0x00`
- Bytes 8-9: Speed impulses (big-endian)
- Remaining bytes: Fixed values
- Byte 13: CRC checksum

### Configuration
- Initial max speed: 25 km/h
- Can be unlocked to 50 km/h by switching modes 3 times
- Throttle normalization: divides raw value by 300
- Temperature reading interval: 50ms
- UART reading interval: 100ms

### Hardware Compatibility
- Standard VESC hardware
- VESC Express (with different UART pin configuration)
- Requires external temperature sensor on ADC3
- UART pins: 20 (TX), 21 (RX) for Express variant

---

## Русский

### Описание
Этот LISP-скрипт предназначен для контроллеров двигателей VESC (Vedder Electronic Speed Controller) для взаимодействия с внешними устройствами через UART-связь. Скрипт обеспечивает управление скоростью, мониторинг температуры и различные функции безопасности для электрических транспортных средств или электровелосипедов.

### Основные функции

1. **UART-связь**
   - Обработка UART-связи на скорости 9600 бод
   - Поддержка стандартного VESC и вариантов Express
   - Реализация проверки CRC для целостности данных

2. **Управление скоростью**
   - Получение команд газа через UART
   - Преобразование значений газа в управление током двигателя
   - Расчет импульсов скорости на основе диаметра колеса
   - Поддержка ограничения скорости (по умолчанию 25 км/ч, может быть увеличена до 50 км/ч)

3. **Мониторинг температуры**
   - Чтение температуры с ADC канала 3 (датчик LM35Z)
   - Усреднение показаний температуры по 20 образцам
   - Переопределение защиты двигателя по температуре

4. **Функции безопасности**
   - Проверка CRC для всех входящих данных
   - Автоматическое переопределение ADC при превышении газа 50%
   - Обнаружение переключения режимов с разблокировкой ограничения скорости
   - Обработка ошибок поврежденных данных

5. **Специальные функции**
   - Звуковая обратная связь на основе скорости (генерация тонов)
   - Счетчик переключения режимов для настройки ограничения скорости
   - Расчет и отображение скорости в реальном времени

### Детали протокола

**Буфер приема (20 байт):**
- Байт 0: Заголовок (должен быть 1)
- Байт 1: Длина (должна быть 20)
- Байт 4: Текущий режим
- Байты 7-8: Диаметр колеса (big-endian)
- Байты 16-17: Значение газа (little-endian)
- Байт 19: Контрольная сумма CRC

**Буфер передачи (14 байт):**
- Фиксированный заголовок: `0x02 0x0E 0x01 0x00 0x80 0x00 0x00 0x00`
- Байты 8-9: Импульсы скорости (big-endian)
- Остальные байты: Фиксированные значения
- Байт 13: Контрольная сумма CRC

### Конфигурация
- Начальная максимальная скорость: 25 км/ч
- Может быть разблокирована до 50 км/ч переключением режимов 3 раза
- Нормализация газа: деление исходного значения на 300
- Интервал чтения температуры: 50мс
- Интервал чтения UART: 100мс

### Совместимость с оборудованием
- Стандартное оборудование VESC
- VESC Express (с другой конфигурацией пинов UART)
- Требуется внешний датчик температуры на ADC3
- Пины UART: 20 (TX), 21 (RX) для варианта Express

### Установка и использование
1. Загрузите скрипт в VESC через VESC Tool
2. Убедитесь, что датчик температуры подключен к ADC3
3. Настройте UART-связь с внешним устройством на 9600 бод
4. Скрипт автоматически запустится и начнет обработку команд

### Примечания
- Скрипт содержит дублированный код (строки повторяются)
- Рекомендуется очистить код перед использованием в продакшене
- Функция `free-bird-song` не реализована полностью
- Некоторые отладочные выводы закомментированы для производительности