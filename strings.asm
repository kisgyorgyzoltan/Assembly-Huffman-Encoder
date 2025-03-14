; Kisgyorgy Zoltan, 532, kzim2149
%include 'mio.inc'



global StrLen, StrCat, StrUpper, StrLower, StrCompact, StrCpy

section .text
	StrCpy: ; esi to edi
		push ecx
		mov ecx,0
		.masol:
			mov bl,[esi+ecx]
			mov [edi+ecx],bl
			inc ecx
			cmp bl,byte 0
			je .kilep
			jmp .masol
		.kilep:
			pop ecx
			ret

	StrLen:
		push	ecx
		push	ebx
		mov		ebx,0
		mov		ecx,0
		mov		eax,0
		.keressl:
			mov		bl,[esi+ecx+1]
			cmp		bl,byte 0
			je		.kilepsl
			inc		ecx
			inc		eax
			jmp		.keressl
		.kilepsl:
			inc		eax
			pop		ebx
			pop		ecx
			ret
	
	StrCat:
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	esi
		push	edi
		
		mov		ecx,-1	;esi index
		mov		edx,-1	;edi index
		
		.megyedin:
			inc		edx
			mov		bl,[edi+edx]
			cmp		bl,byte 0
			je		.esimasol
			jmp		.megyedin
			
		.esimasol:
			inc		ecx
			mov		bl,[esi+ecx]
			mov		[edi+edx],bl
			inc		edx
			cmp		bl,byte 0
			je		.kilepsc
			jmp		.esimasol
			
		.kilepsc:
			pop		edi
			pop		esi
			pop		edx
			pop		ecx
			pop		ebx
			pop		eax
			ret
	StrUpper:
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	edi
		
		mov		ecx,-1
		
		.tovabbsu:
			inc		ecx
			mov		bl,[esi+ecx]
			cmp		bl,byte 0
			je		.kilepsu
			cmp		bl,'z'
			jg		.tovabbsu
			cmp		bl,'a'
			jl		.tovabbsu
			sub		bl,32
			mov		[esi+ecx],bl
			jmp		.tovabbsu

		.kilepsu:
			pop		edi
			pop		edx
			pop		ecx
			pop		ebx
			pop		eax
			ret
	StrLower:
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	edi
		
		mov		ecx,-1
		
		.tovabbsl:
			inc		ecx
			mov		bl,[esi+ecx]
			cmp		bl,byte 0
			je		.kilepsl
			cmp		bl,'Z'
			jg		.tovabbsl
			cmp		bl,'A'
			jl		.tovabbsl
			add		bl,32
			mov		[esi+ecx],bl
			jmp		.tovabbsl

		.kilepsl:
			pop		edi
			pop		edx
			pop		ecx
			pop		ebx
			pop		eax
			ret
			
	StrCompact:
		push	eax
		push	ebx
		push	ecx
		push	edx
		push	esi
		
		mov		ecx,-1	;esi index
		mov		edx,0	;edi index
		.megycomp:
			inc		ecx
			mov		bl,[esi+ecx]
			cmp		bl,9
			je		.megycomp
			cmp		bl,13
			je		.megycomp
			cmp		bl,10
			je		.megycomp
			cmp		bl,32
			je		.megycomp
			mov		[edi+edx],bl
			mov		bl,[esi+ecx]
			cmp		bl,byte 0
			je		.kilepcomp
			inc		edx
			jmp		.megycomp
			
		.kilepcomp:
			pop		esi
			pop		edx
			pop		ecx
			pop		ebx
			pop		eax
			ret