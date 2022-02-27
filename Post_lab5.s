; Archivo:	Postlab5.s
; Dispositivo:	PIC16F887
; Autor:	Saby Andrade
; Compilador:	pic-as (v2.35), MPLABX V5.50
;                
; Programa:	En decimal (centena, unidades y decenas) Incrementos y decrementos en el Timer0 ocupando interrupciones y un Contador binario de 8 bits
; Hardware:	Tres displas de 7 segmentos en el PORTD en dec.	
;
; Creado:	21 Febrero 2022
; Última modificación: 26 de febrero 
    
PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
 
; ------- VARIABLES EN MEMORIA --------
BMODO EQU 0	    ;Equivalencia de BMODO = 0
BACCION EQU 1	    ;Equivalencia de BACCION = 1
 
PSECT udata_bank0
 //Variables temporales
    Conta_dor:		DS 1	;1 Byte
    Sis_Cente:		DS 1	;1 Byte
    Sis_Decen:		DS 1	;1 Byte
    Sis_Unida:		DS 1	;1 Byte
    Display_Bandera:	DS 1	;1 Byte
    Display_:		DS 3	;3 Byte
  
; -------------- MACROS --------------- 
  
  Timer0_Reset MACRO		;Se crea una macro llamada "Timer0_Reset"
    BANKSEL TMR0	       ;Direccionar al Banco 00
    MOVLW   217		       ; Carga literal en el registro W
    MOVWF   TMR0	       ; Configuración que tenga 10ms de retardo
    BCF	    T0IF	       ; Limpia la bandera de interrupción
    ENDM
  
; ------- Status para interrupciones --------
PSECT udata_shr		; Memoria compartida
    Temp_W:			DS 1	;1 Byte
    Temp_Status:		DS 1	;1 Byte
    
    
PSECT resVect, class=CODE, abs, delta=2
		   
;------------ VECTOR RESET --------------
ORG 00h			       ; Posición 0000h para el reset
resVect:
    PAGESEL main	       ;Cambio de página		
    GOTO    main
    
PSECT inVect, class=CODE, abs, delta=2
			
;------- VECTOR INTERRUPCIONES ----------

ORG 04h				;Posición 0004h para las interrupciones
    
PUSH:				; Se mueve la instruccion de la PC a pila
    MOVWF   Temp_W		; del registro W a la variable "Temp_W"	
    SWAPF   STATUS, W		; Swap de nibbles del STATUS y se almacena en el registro W
    MOVWF   Temp_Status    	; Rutina de interrupción
    
ISR:
    BTFSC   RBIF		; Cambio de bandera del PORTB No=0 Si=1. Salta al estar apagada
    CALL    IOCB_Interrup_Config	;Se llama la subrutina
    BANKSEL PORTA		;Se direcciona al banco 00
    
    BTFSC   T0IF		;Cambio del TMR0 del PORTB No=0 Si=1. Salta al estar apagada
    CALL    TMR0_Interrup		;Se llama la subrutina
	
    
POP:				; Se mueve la instrucción de la pila a la PC
    SWAPF   Temp_W, W		;Swap de nibbles de la variable "Temp_W" y se almacena en el registro W
    MOVWF   STATUS		;Se mueve el registro W a STATUS	
    SWAPF   Temp_W, F		;Swap de nibbles de la variable "Temp_W" y se almacena en la variable "Temp_W"
    SWAPF   Temp_W, W		;Swap de nibbles de la variable "Temp_W" y se almacena en el registro W
    RETFIE			
    
    
PSECT code, delta=2, abs
ORG 100h			
;------------- CONFIGURACION ------------
main:
    CALL    IO_Config		;Se llama la subrutina de configuración de entradas /salidas	
    CALL    Reloj_Config	;Se llama la subrutina de configuración del reloj
    CALL    TMR0_Config		;Se llama la subrutina de configuración del TMR0
    CALL    Interrup_Config	;Se llama la subrutina de configuración de interrupciones
    CALL    IOCB_Config		;Se llama la subrutina de configuración de interrupción en el puerto B 
    BANKSEL PORTA		;Se direcciona al banco 00	

;----------LOOP PRINCIPAL---------------
loop:	
    CALL    Dec_Number		;Se llama la subrutina de movimiento de valores decimales a 7Seg
    CALL    Centenas_Alcanzar	;Se llama la subrutina para obtener los sistemas de: centenas/decenas/unidades
    GOTO    loop		;Regresa a revisar
    
;------------- SUBRUTINAS ---------------

IO_Config:			
    BANKSEL ANSEL		;Direcciona al banco 11
    CLRF    ANSEL		;Entradas o salidas digitales
    CLRF    ANSELH		;Entradas o salidas digitales
    
    BANKSEL TRISA		;Se direcciona al banco 01
    BSF	    TRISB, BMODO	;RB0 Como entrada
    BSF	    TRISB, BACCION	;RB1 Como entrada
    CLRF    TRISA		;El puerto A como salida
    CLRF    TRISC		;El puerto C como salida
    CLRF    TRISD		;El puerto D como salida
    BCF	    OPTION_REG,	7	;RBPU de las resistencias como pull-up (habilitan)
    BSF	    WPUB,  BMODO	;Pull-up en RB0 se habilitan
    BSF	    WPUB, BACCION	;Pull-up en RB1 se habilitan
    
    BANKSEL PORTA		;Se direcciona al banco 00
    CLRF    PORTA		;Limpia el puerto A
    CLRF    PORTB		;Limpia el puerto B
    CLRF    PORTC		;Limpia el puerto C
    CLRF    PORTD		;Limpia el puerto D
    CLRF    Sis_Cente		;Limpia la variable "Sis_Cente"
    CLRF    Sis_Decen		;Limpia la variable "Sis_Decen"
    CLRF    Sis_Unida		;Limpia la variable "Sis_Unida"
    CLRF    Display_Bandera	;Limpia la variable "Display_Bandera"
    RETURN			;Se regresa
    
Reloj_Config:			
    BANKSEL OSCCON		;Direcciona al banco 01	
    
    //S= 1, C=0
    BSF	    OSCCON, 0		;SCS en 1, se configura a reloj interno
    BSF	    OSCCON, 6		;Bit 6 en 1
    BSF	    OSCCON, 5		;Bit 5 en 1
    BCF	    OSCCON, 4		;Bit 4 en 0
    ; Con una frecuencia interna del oscilador  a 4MHZ (IRCF<2:0> -> 110 4MHz)
    RETURN			;Se regresa
  
TMR0_Config:		
    BANKSEL OPTION_REG		;Se direcciona al banco 01
    
  //S= 1, C=0
    BCF	OPTION_REG, 5		;TMR0 como temporizador
    BCF	OPTION_REG, 3		;Prescaler a TMR0
    BSF	OPTION_REG, 2		;Bit 2 en 1
    BSF	OPTION_REG, 1		;Bit 1 en 1
    BSF	OPTION_REG, 0		;Bit 0 en 1
    ;Prescaler en 256
    Timer0_Reset			;Se llama la Macro
    RETURN			;Se regresa
    

    
Interrup_Config:		
    BANKSEL INTCON		
    BSF	    GIE			;Las interrupciones globales se habilitan
    BSF	    RBIE		;El cambio de estado en el puerto B se habilita
    BCF	    RBIF		; El cambio de bandera se habilita en el puerto	B
    BSF	    T0IE		;La interrupción en el Timer0 se habilita
    BCF	    T0IF		;En el timer0 se limpia la bandera
    RETURN			;Se regresa
    
IOCB_Config:			;Interrupción en cambio de registro en el puerto B
    BANKSEL TRISA		;Se direcciona al banco 01
    BSF	    IOCB,   BMODO	;Se cambia el valor de B con la interrupción 
    BSF	    IOCB,  BACCION	;Se cambia el valor de B con la interrupción
    
    BANKSEL PORTA		;Se direcciona al banco 00
    MOVF    PORTB,  W		;Compara con W cuando finaliza la condición mismatch
    BCF	    RBIF		;La bandera de cambio del puerto B se limpia
    RETURN			;Se regresa
    
IOCB_Interrup_Config:		
    BANKSEL PORTA		;Se direcciona al banco 00
    BTFSS   PORTB, BMODO	;Salta una linea si se presiona en el puerto B pin 0 (RB0)
    
    
    INCF    PORTA		;Incrementa en el Puerto A
    BTFSS   PORTB,  BACCION	;Salta una linea si se presiona en el puerto B pin 1 (RB1)
    DECF    PORTA		;Decrementa en el puerto A
    BCF	RBIF			;La bandera que realiza el cambio de estado en el puerto B se limpia
    
    RETURN			;Se regresa
    
    
    
TMR0_Interrup:
    Timer0_Reset		;Llama el macro que reinicia el Timer 0 en el tiempo de 10ms
    CALL    Dec_Number_		;LLama la subrutina
    RETURN			;Se regresa
 
Dec_Number_:  //ENSEÑA		
    BCF	    PORTD,  0		;Display de centena se limpia 
    BCF	    PORTD,  1		;Display de decena se limpia
    BCF	    PORTD,  2		;Display de unidades se limpia
    
    //La variable está en bit 0
    BTFSC   Display_Bandera,    0	;Si está apagada se salta esta línea que es de la bandera de display de centena 
    goto    Display_3		;Se mueve al display de centena si está encendida
    
    //La variable está en bit 1
    BTFSC   Display_Bandera,    1	;Si está apagada se salta esta línea que es de la bandera de display de decena
    GOTO    Display_2		;Se mueve al display de decena si está encendida
    
    //La variable está en bit 2
    BTFSC   Display_Bandera,    2	;Si está apagada se salta esta línea que es de la bandera de display de unidades
    GOTO    Display_1		;Se mueve al display de unidades si está encendida
    
    
    
Dec_Number:			
    MOVF    Sis_Unida,	W	;De la variable "Sis_Unida" se mueve hacia el registro W
    CALL    Table		;Se llama la tabla (para buscar el valor a cargar que se encuentra en el puerto C)
    MOVWF   Display_		;En una nueva variable llamada "Display_1" y se guarda
    
    MOVF    Sis_Decen, W	;De la variable "Sis_Decen" se mueve hacia el registro W
    CALL    Table		 ;Se llama la tabla (para buscar el valor a cargar que se encuentra en el puerto C)
    MOVWF   Display_+1		 ;En una nueva variable llamada "Display_2" y se guarda
    
    MOVF    Sis_Cente,	W	 ;De la variable "Sis_Cente" se mueve hacia el registro W
    CALL    Table		 ;Se llama la tabla (para buscar el valor a cargar que se encuentra en el puerto C)
    MOVWF   Display_+2		 ;En una nueva variable llamada "Display_3" y se guarda
    RETURN			;Se regresa
    
ORG 200h ;Posición del Código
    ;Tabla
Table:
    CLRF    PCLATH		
    BSF	    PCLATH, 1	
    ANDLW   0x0F		
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F
       
Display_1:
    MOVF    Display_,	W	;El valor se mueve de unidades hacia el registro W
    MOVWF   PORTC		;El display se enseña
    BSF	    PORTD,  2		;El display de unidades se enciende
    BCF	    Display_Bandera,  2 ;La bandera de unidades se apaga
    BSF	    Display_Bandera,  1	;La bandera de decenas se enciende
    RETURN			;Se regresa
    
Display_2:
    MOVF    Display_+1, W	;El valor se mueve de decena hacia el registro W
    MOVWF   PORTC		;El display se enseña 
    BSF	    PORTD,  1		;El display de decenas se enciende
    BCF	    Display_Bandera,  1	;La bandera de decenas se apaga
    BSF	    Display_Bandera,  0 ;La bandera de centenas se enciende
    RETURN			;Se regresa
    
Display_3:
    MOVF    Display_+2, W	;El valor se mueve de centena hacia el registro W
    MOVWF   PORTC		;El display se enseña
    BSF	    PORTD,  0		;El display de centenas se enciende
    BCF	    Display_Bandera,  0	;La bandera de centena se apaga
    BSF	    Display_Bandera,  2	;La bandera de unidades se enciende
    RETURN			;Se regresa
      
Centenas_Alcanzar:
    CLRF    Sis_Cente		;Limpia la variable
    CLRF    Sis_Decen		;Limpia la variable
    CLRF    Sis_Unida		;Limpia la variable
    
    MOVF    PORTA,  W		;El valor se mueve del puerto A hacia el registro W
    MOVWF   Conta_dor		;Del registro W a la variable "Conta_dor" se mueve el valor
    MOVLW   100			;El valor de 100 se mueve hacia el registro W
    SUBWF   Conta_dor,  F	;Se guarda en la variable "Conta_dor" después de restar 100 a la variable "Conta_dor"
    INCF    Sis_Cente		;En la variable "Sis_Cente" se aumenta en 1
    
    //Apagado valor negativo, encendido valor positivo
    BTFSC   STATUS, 0		;Se comprueba que la bandera de BORRON esté apagada
    
    GOTO    $-4			;Se regresa 4 instrucciones previas al no estar apagada	
    DECF    Sis_Cente		;Se decrece 1 a la variable "Sis_Cente" al estar apagada
 
    //Se vuelve a reevaluar el valor que tiene la variable "Conta_dor" después del incremento de valor
    MOVLW   100			;El valor de 100 se mueve hacia el registro W
    ADDWF   Conta_dor,  F	;Para ser positivo, se añade los 100 al momento negativo que se encuentra la variable "Conta_dor"
    CALL    Decenas_Alcanzar	;Se llama la subrutina
    RETURN			;Se regresa
    
Decenas_Alcanzar:
    MOVLW   10			;El valor de 10 se mueve hacia el registro W
    SUBWF   Conta_dor,  F		;Se guarda en la variable "Conta_dor" después de restar 10  a la variable "Conta_dor"
    INCF    Sis_Decen		;En la variable "Sis_Decen" se aumenta en 1
    
    //Apagado valor negativo, encendido valor positivo
    BTFSC   STATUS, 0		;Se comprueba que la bandera de BORRON este apagada 
    GOTO    $-4			;Se regresa 4 instrucciones previas al no estar apagada
    DECF    Sis_Decen		;Se decrece 1 a la variable "Sis_Decen" al estar apagada
    
    //Se vuelve a reevaluar el valor que tiene la variable "Conta_dor" después del incremento de valor
    MOVLW   10			;El valor de 10 se mueve hacia el registro W
    ADDWF   Conta_dor, F	;Para ser positivo, se añade los 10 al momento negativo que se encuentra la variable "Conta_dor"
    CALL    Unidades_Alcanzar	;Se llama la subrutina
    RETURN			;Se regresa
    
    
Unidades_Alcanzar:   
    MOVLW   1			;El valor de 1 se mueve hacia el registro de W
    SUBWF   Conta_dor,  F	;Se guarda en la variable "Conta_dor" después de restar 1  a la variable "Conta_dor"
    INCF    Sis_Unida		;En la variable "Sis_Unida" se aumenta en 1
   
  //Apagado valor negativo, encendido valor positivo
    BTFSC   STATUS, 0		;Se comprueba que la bandera de BORRON este apagada 
    GOTO    $-4			;Se regresa 4 instrucciones previas al no estar apagada
    DECF    Sis_Unida		;Se decrece 1 a la variable "Sis_Unida" al estar apagada
    
    //Se vuelve a reevaluar el valor que tiene la variable "Conta_dor" después del incremento de valor    
    MOVLW   1			;El valor de 1 se mueve hacia el registro W
    ADDWF   Conta_dor,  F	;Para ser positivo, se añade los 1 al momento negativo que se encuentra la variable "Conta_dor"
    RETURN			;Se regresa

END





